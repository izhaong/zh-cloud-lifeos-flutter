import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-113：导出当前笔记为 Markdown 文本；导入创建一个笔记（F-15）。
void main() {
  const delta =
      '{"ops":[{"insert":"买牛奶\\n"},{"insert":"鸡蛋","attributes":{"list":"unchecked"}},{"insert":"\\n"}]}';

  testWidgets('导出含标题与清单，导入创建新笔记', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: NoteEditorPage(
            folderId: 'f1',
            note: Note(
              id: 'n1',
              folderId: 'f1',
              title: '购物',
              bodyDelta: delta,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 导出
    await tester.tap(find.byKey(const ValueKey('note_editor_more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_export_markdown')));
    await tester.pumpAndSettle();
    final exported = tester
        .widget<SelectableText>(find.byKey(const ValueKey('note_export_text')))
        .data!;
    expect(exported, contains('# 购物'));
    expect(exported, contains('- [ ] 鸡蛋'));
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    // 导入
    await tester.tap(find.byKey(const ValueKey('note_editor_more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_import_markdown')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note_import_text')),
      '# 导入标题\n\n正文内容\n- [x] 已完成',
    );
    await tester.tap(find.byKey(const ValueKey('note_import_submit')));
    await tester.pumpAndSettle();

    final notes = await repo.watchNotes().first;
    final imported = notes.firstWhere((n) => n.title == '导入标题');
    expect(imported.folderId, 'f1');
    expect(imported.bodyText, contains('正文内容'));
    expect(imported.checklistDone, 1);
  });
}
