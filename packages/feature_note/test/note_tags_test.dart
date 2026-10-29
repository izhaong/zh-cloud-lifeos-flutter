import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-106：给笔记打标签；侧栏智能文件夹按标签过滤（F-08）。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<InMemoryNoteRepository> seeded() async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertFolder(
      const NoteFolder(
        id: 's1',
        name: '工作标签',
        smart: true,
        filterJson: '{"tagNames":["工作"]}',
      ),
    );
    await repo.upsertNote(
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: '带标签',
        bodyDelta: '{"ops":[{"insert":"a\\n"}]}',
        tagNames: ['工作'],
      ),
    );
    await repo.upsertNote(
      const Note(
        id: 'n2',
        folderId: 'f1',
        title: '无标签',
        bodyDelta: '{"ops":[{"insert":"b\\n"}]}',
      ),
    );
    return repo;
  }

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

  testWidgets('编辑器加标签并保存', (tester) async {
    final repo = await seeded();
    await pump(tester, repo);

    await tester.tap(find.text('无标签'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note_editor_tag_input')),
      '私人',
    );
    await tester.tap(find.byKey(const ValueKey('note_editor_tag_add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note_editor_tag_私人')), findsOneWidget);

    // #390：不再有「保存」按钮——输入后等去抖窗口过去即自动落库
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final notes = await repo.watchNotes().first;
    final saved = notes.firstWhere((n) => n.id == 'n2');
    expect(saved.tagNames, contains('私人'));
  });

  testWidgets('点智能文件夹只显示带该标签的笔记', (tester) async {
    final repo = await seeded();
    await pump(tester, repo);
    expect(find.text('带标签'), findsOneWidget);
    expect(find.text('无标签'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note_sidebar_s1')));
    await tester.pumpAndSettle();

    expect(find.text('带标签'), findsOneWidget);
    expect(find.text('无标签'), findsNothing);
  });
}
