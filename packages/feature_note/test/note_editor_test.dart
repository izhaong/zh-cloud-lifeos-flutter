import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-102：新建并加粗（F-05；契约 §5、§8）。
/// 新笔记输入标题，正文加粗「买菜」→ 保存后 bodyDelta 含 bold 属性，列表可见标题。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('新建笔记：标题 + 加粗正文保存进 bodyDelta', (tester) async {
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

    // 新建 → 编辑器
    await tester.tap(find.byKey(const ValueKey('note_new')));
    await tester.pumpAndSettle();
    expect(find.text('新建备忘录'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('note_editor_title')), '买菜清单');

    // 正文写入「买菜」并加粗（编辑器控制器 = flutter_quill）
    final editor = tester.widget<quill.QuillEditor>(find.byType(quill.QuillEditor));
    final controller = editor.controller;
    controller.replaceText(0, 0, '买菜',
        const TextSelection.collapsed(offset: 2));
    controller.formatText(0, 2, quill.Attribute.bold);
    await tester.pumpAndSettle();
    expect(controller.document.toPlainText(), contains('买菜'),
        reason: '编辑器控制器里已有正文');
    expect(controller.document.toDelta().toJson().toString(), contains('bold'),
        reason: '编辑器控制器里已有加粗属性');

    await tester.tap(find.byKey(const ValueKey('note_editor_save')));
    await tester.pumpAndSettle();

    // 回到列表：标题可见
    expect(find.text('买菜清单'), findsOneWidget);

    // 落库：bodyDelta 含 bold，bodyText 为纯文本
    final saved = await repo.watchNotes().first;
    final note = saved.single;
    expect(note.title, '买菜清单');
    expect(note.bodyDelta, contains('"bold":true'));
    expect(note.bodyDelta, contains('买菜'));
    expect(note.bodyText, contains('买菜'));
  });

  testWidgets('点列表笔记进入编辑器并可改标题保存', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;

    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(const Note(
      id: 'n1',
      folderId: 'f1',
      title: '旧标题',
      bodyDelta: '{"ops":[{"insert":"正文\\n"}]}',
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: NoteScaffold()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('旧标题'));
    await tester.pumpAndSettle();
    expect(find.text('编辑备忘录'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('note_editor_title')), '新标题');
    await tester.tap(find.byKey(const ValueKey('note_editor_save')));
    await tester.pumpAndSettle();

    expect(find.text('新标题'), findsOneWidget);
    final saved = await repo.watchNotes().first;
    expect(saved.single.title, '新标题');
  });
}
