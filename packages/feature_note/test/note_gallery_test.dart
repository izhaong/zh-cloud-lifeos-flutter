import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-108：列表/画廊两种视图切换，笔记集合不变（F-10）。
void main() {
  testWidgets('切画廊仍显示同一批笔记，切回列表不变', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;

    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    for (final id in ['n1', 'n2']) {
      await repo.upsertNote(
        Note(
          id: id,
          folderId: 'f1',
          title: '笔记$id',
          bodyDelta: '{"ops":[{"insert":"内容$id\\n"}]}',
        ),
      );
    }

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
    expect(find.text('笔记n1'), findsOneWidget);
    expect(find.text('笔记n2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note_view_toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note_gallery_grid')), findsOneWidget);
    expect(find.text('笔记n1'), findsOneWidget);
    expect(find.text('笔记n2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note_view_toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note_gallery_grid')), findsNothing);
    expect(find.text('笔记n1'), findsOneWidget);
    expect(find.text('笔记n2'), findsOneWidget);
  });
}
