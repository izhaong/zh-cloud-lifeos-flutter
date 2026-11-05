import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_note/feature_note.dart';

/// TC-NOTE-UI-111 的持久半边（flutter#394）：记录设置改完要能重启读回。
///
/// 「重启」在 Provider 层就是换一个 ProviderContainer 但复用同一份偏好仓库——
/// 每条正向断言都配一条反对照（换新仓库必须回默认），否则测的可能是内存态。
void main() {
  ProviderContainer containerWith(NotePreferenceRepository prefs) {
    final container = ProviderContainer(
      overrides: [notePreferenceRepositoryProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// 裸 `container.read` 不留住订阅（无监听者时流根本不开），先挂监听再轮询。
  /// 偏好流是 `async*` + broadcast：首值在微任务之后才到，`.future` 在这种
  /// 「永不为完成」的流上等不到，只能轮询 `.value`。
  Future<void> prime(ProviderContainer container) async {
    container.listen(notePreferenceProvider, (_, _) {});
    container.listen(noteSettingsProvider, (_, _) {});
    for (var i = 0; i < 200; i++) {
      if (container.read(notePreferenceProvider).value != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('偏好流 1s 内没推首值：不是「重启回默认」，是订阅没建立');
  }

  Future<NotePreference> saved(NotePreferenceRepository prefs) =>
      prefs.watchPreference().first;

  test('改排序后重建容器（模拟重启）仍是该档，且真的落了库', () async {
    final prefs = InMemoryNotePreferenceRepository();
    final first = containerWith(prefs);
    await prime(first);

    first.read(noteSettingsProvider.notifier).setSortMode(NoteSortMode.updated);
    expect((await saved(prefs)).sortMode, 'updated', reason: '不落库的话下一条断言只是读内存');

    final restarted = containerWith(prefs);
    await prime(restarted);
    expect(restarted.read(noteSettingsProvider).sortMode, NoteSortMode.updated);
  });

  test('对照：换新仓库（等价于没落库）排序回 custom（防恒真）', () async {
    final old = InMemoryNotePreferenceRepository();
    final first = containerWith(old);
    await prime(first);
    first.read(noteSettingsProvider.notifier).setSortMode(NoteSortMode.title);
    await saved(old);

    final fresh = containerWith(InMemoryNotePreferenceRepository());
    await prime(fresh);
    expect(
      fresh.read(noteSettingsProvider).sortMode,
      NoteSortMode.custom,
      reason: '换了存储还是「按标题」，说明读的是内存而不是仓库',
    );
  });

  test('默认文件夹可设可清（「跟随当前文件夹」是可达的一档）', () async {
    final prefs = InMemoryNotePreferenceRepository();
    final container = containerWith(prefs);
    await prime(container);

    container
        .read(noteSettingsProvider.notifier)
        .setDefaultFolder('folder.work');
    expect((await saved(prefs)).defaultFolderId, 'folder.work');

    container.read(noteSettingsProvider.notifier).setDefaultFolder(null);
    expect(
      (await saved(prefs)).defaultFolderId,
      isNull,
      reason: 'null 要走显式清空通道，不能留着旧值',
    );
  });

  test('存量脏档位串退回 custom，不炸设置页', () async {
    final prefs = InMemoryNotePreferenceRepository();
    await prefs.savePreference(const NotePreference(sortMode: 'notARealMode'));

    final container = containerWith(prefs);
    await prime(container);
    expect(container.read(noteSettingsProvider).sortMode, NoteSortMode.custom);
  });

  testWidgets('TC-NOTE-UI-111 设置页勾的是已存档位（不是硬编码默认）', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final prefs = InMemoryNotePreferenceRepository();
    await prefs.savePreference(
      const NotePreference(defaultFolderId: 'folder.work', sortMode: 'title'),
    );
    final noteRepo = InMemoryNoteRepository();
    await noteRepo.upsertFolder(
      const NoteFolder(id: 'folder.work', name: '工作'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(noteRepo),
          notePreferenceRepositoryProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final check = find.byIcon(CupertinoIcons.check_mark);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('note_sort_title')),
        matching: check,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('note_sort_custom')),
        matching: check,
      ),
      findsNothing,
      reason: '勾两行就等于没量到档位',
    );
    expect(find.text('工作'), findsWidgets, reason: '默认文件夹行要显示已存的名字');
  });

  testWidgets('点档位当场写库（不手动 reload）', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final prefs = InMemoryNotePreferenceRepository();
    final noteRepo = InMemoryNoteRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(noteRepo),
          notePreferenceRepositoryProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note_sort_updated')));
    await tester.pumpAndSettle();

    expect((await saved(prefs)).sortMode, 'updated');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('note_sort_updated')),
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsOneWidget,
    );
  });
}
