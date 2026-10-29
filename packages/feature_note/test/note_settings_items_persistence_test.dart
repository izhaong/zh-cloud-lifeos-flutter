import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_note/feature_note.dart';

/// #392 的持久半边：新增两格（按日期分组、开头格式）要能重启读回，
/// 而且「改一格不能把其他格打回默认」——四格并存之后这是最容易踩的写法。
///
/// 每条正向断言都配一条换新仓库的反对照，否则测到的可能只是内存态。
void main() {
  ProviderContainer containerWith(NotePreferenceRepository prefs) {
    final container = ProviderContainer(
      overrides: [notePreferenceRepositoryProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

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

  test('改分组与开头格式后重建容器仍是该档，且真的落了库', () async {
    final prefs = InMemoryNotePreferenceRepository();
    final first = containerWith(prefs);
    await prime(first);

    final notifier = first.read(noteSettingsProvider.notifier);
    notifier.setGroupByDate(false);
    notifier.setBeginWith(NoteBeginWithMode.checklist);

    final stored = await saved(prefs);
    expect(stored.groupByDate, isFalse, reason: '不落库的话下一条断言只是读内存');
    expect(stored.beginWith, 'checklist');

    final restarted = containerWith(prefs);
    await prime(restarted);
    final settings = restarted.read(noteSettingsProvider);
    expect(settings.groupByDate, isFalse);
    expect(settings.beginWith, NoteBeginWithMode.checklist);
  });

  test('对照：换新仓库后两格回默认（分组开、开头无）', () async {
    final old = InMemoryNotePreferenceRepository();
    final first = containerWith(old);
    await prime(first);
    first.read(noteSettingsProvider.notifier).setGroupByDate(false);
    await saved(old);

    final fresh = containerWith(InMemoryNotePreferenceRepository());
    await prime(fresh);
    final settings = fresh.read(noteSettingsProvider);
    expect(
      settings.groupByDate,
      isTrue,
      reason: '换了存储还是不分组，说明读的是内存而不是仓库',
    );
    expect(settings.beginWith, NoteBeginWithMode.nothing);
  });

  test('改开头格式不会把分组/排序/默认文件夹打回默认', () async {
    final prefs = InMemoryNotePreferenceRepository();
    final container = containerWith(prefs);
    await prime(container);

    final notifier = container.read(noteSettingsProvider.notifier);
    // 连点四格、中间不等回推：上一笔保存的回推不能把已写的格子打回旧档
    // （#392 把偏好从两格扩到四格后，这条路径的覆盖面变大了）。
    notifier.setDefaultFolder('folder.work');
    notifier.setSortMode(NoteSortMode.title);
    notifier.setGroupByDate(false);
    notifier.setBeginWith(NoteBeginWithMode.body);

    final stored = await saved(prefs);
    expect(stored.defaultFolderId, 'folder.work');
    expect(stored.sortMode, 'title');
    expect(stored.groupByDate, isFalse);
    expect(stored.beginWith, 'body');

    // 只动一格：其余三格必须原样带过。
    notifier.setBeginWith(NoteBeginWithMode.title);
    final after = await saved(prefs);
    expect(after.defaultFolderId, 'folder.work');
    expect(after.sortMode, 'title');
    expect(after.groupByDate, isFalse);
    expect(after.beginWith, 'title');
  });

  test('存量脏档位串退回 nothing，不炸设置页', () async {
    final prefs = InMemoryNotePreferenceRepository();
    await prefs.savePreference(
      const NotePreference(beginWith: 'notARealMode', groupByDate: false),
    );

    final container = containerWith(prefs);
    await prime(container);
    final settings = container.read(noteSettingsProvider);
    expect(settings.beginWith, NoteBeginWithMode.nothing);
    expect(
      settings.groupByDate,
      isFalse,
      reason: '脏值只该废掉那一格，不能顺手重置别的格子',
    );
  });
}
