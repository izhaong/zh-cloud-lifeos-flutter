import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-110：锁定后列表不显示正文，解锁前不能编辑（F-12）。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> pump(WidgetTester tester, InMemoryNoteRepository repo) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;
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
  }

  testWidgets('编辑器锁定后列表只显示已锁定', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: '日记',
        bodyDelta: '{"ops":[{"insert":"秘密正文\\n"}]}',
      ),
    );
    await pump(tester, repo);
    expect(find.textContaining('秘密正文'), findsOneWidget);

    await tester.tap(find.text('日记'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_editor_lock')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note_lock_password')),
      '1234',
    );
    await tester.tap(find.byKey(const ValueKey('note_lock_confirm')));
    await tester.pumpAndSettle();

    final locked = (await repo.watchNotes().first).single;
    expect(locked.locked, isTrue);
    expect(find.text('已锁定'), findsOneWidget);
    expect(find.textContaining('秘密正文'), findsNothing);
  });

  testWidgets('锁定笔记需解锁后才能编辑', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: '日记',
        bodyDelta: '{"ops":[{"insert":"秘密正文\\n"}]}',
        locked: true,
      ),
    );
    await pump(tester, repo);
    expect(find.text('已锁定'), findsOneWidget);
    expect(find.textContaining('秘密正文'), findsNothing);

    await tester.tap(find.text('日记'));
    await tester.pumpAndSettle();
    expect(find.text('解锁备忘录'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('note_unlock_password')),
      '1234',
    );
    await tester.tap(find.byKey(const ValueKey('note_unlock_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('编辑备忘录'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('note_editor_title')),
      '已解锁',
    );
    await tester.tap(find.byKey(const ValueKey('note_editor_save')));
    await tester.pumpAndSettle();

    final saved = (await repo.watchNotes().first).single;
    expect(saved.locked, isFalse);
    expect(saved.title, '已解锁');
  });
}
