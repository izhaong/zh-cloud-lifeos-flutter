import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-111：设置默认文件夹与排序（标题/修改时间），本地偏好（F-13）。
void main() {
  testWidgets('切换按标题/按修改时间排序生效', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;

    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: 'Beta',
        bodyDelta: '{"ops":[{"insert":"b\\n"}]}',
        clientUpdatedAt: 2000,
      ),
    );
    await repo.upsertNote(
      const Note(
        id: 'n2',
        folderId: 'f1',
        title: 'Alpha',
        bodyDelta: '{"ops":[{"insert":"a\\n"}]}',
        clientUpdatedAt: 1000,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 自定义：仓库序（id 升序）乙在前
    expect(
      tester.getTopLeft(find.text('Beta')).dy,
      lessThan(tester.getTopLeft(find.text('Alpha')).dy),
    );

    // 按标题：甲 < 乙
    await tester.tap(find.byKey(const ValueKey('note_settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_sort_title')));
    await tester.pumpAndSettle();
    // cupertino_ui 包自带同名 BackButton 类，tester.pageBack 只认 SDK 类，改为显式点返回键
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('Beta')).dy),
    );

    // 按修改时间：乙（2000）在甲（1000）前
    await tester.tap(find.byKey(const ValueKey('note_settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_sort_updated')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Beta')).dy,
      lessThan(tester.getTopLeft(find.text('Alpha')).dy),
    );
  });

  testWidgets('默认文件夹用于新建笔记', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;

    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertFolder(const NoteFolder(id: 'f2', name: '生活'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note_settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_default_folder')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生活').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note_quick_capture')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note_quick_title')),
      '默认目录',
    );
    await tester.tap(find.byKey(const ValueKey('note_quick_save')));
    await tester.pumpAndSettle();

    final saved = (await repo.watchNotes().first).single;
    expect(saved.folderId, 'f2');
  });
}
