import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-109：壳上快速记录，只写标题与正文，保存进默认文件夹（F-11）。
void main() {
  testWidgets('快速记录保存到默认文件夹', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;

    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: NoteScaffold()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note_quick_capture')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('note_quick_title')), '闪现想法');
    await tester.enterText(
        find.byKey(const ValueKey('note_quick_body')), '记一笔');
    await tester.tap(find.byKey(const ValueKey('note_quick_save')));
    await tester.pumpAndSettle();

    final saved = (await repo.watchNotes().first).single;
    expect(saved.title, '闪现想法');
    expect(saved.folderId, 'f1');
    expect(saved.bodyText, contains('记一笔'));
    expect(find.text('闪现想法'), findsOneWidget);
  });
}
