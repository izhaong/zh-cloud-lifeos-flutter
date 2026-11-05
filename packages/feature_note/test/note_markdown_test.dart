import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
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
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteEditorPage(
            folderId: 'f1',
            note: Note(id: 'n1', folderId: 'f1', title: '购物', bodyDelta: delta),
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
        .widget<Text>(find.byKey(const ValueKey('note_export_text')))
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

  // #237：旧落点的清单属性要归一到行尾 op，否则 quill 不建 Block、
  // 行首勾选框渲染不出来（渲染与内核计数口径不一致）。
  group('normalizeListAttributes', () {
    test('把文本 op 上的 list 搬到行尾 op', () {
      const legacy =
          '{"ops":[{"insert":"事项一","attributes":{"list":"unchecked"}},'
          '{"insert":"\\n"}]}';
      final out = NoteMarkdownCodec.normalizeListAttributes(legacy);
      final ops = ((jsonDecode(out) as Map)['ops'] as List).cast<Map>();
      expect(ops, hasLength(2));
      expect(ops[0]['insert'], '事项一');
      expect(ops[0]['attributes'], isNull, reason: 'list 已搬走，不该残留');
      expect(ops[1]['insert'], '\n');
      expect((ops[1]['attributes'] as Map)['list'], 'unchecked');
    });

    test('行内其它属性留在文本 op 上', () {
      const legacy =
          '{"ops":[{"insert":"事项一","attributes":{"list":"checked","bold":true}},'
          '{"insert":"\\n"}]}';
      final ops =
          ((jsonDecode(NoteMarkdownCodec.normalizeListAttributes(legacy))
                      as Map)['ops']
                  as List)
              .cast<Map>();
      expect((ops[0]['attributes'] as Map)['bold'], true);
      expect((ops[0]['attributes'] as Map).containsKey('list'), isFalse);
      expect((ops[1]['attributes'] as Map)['list'], 'checked');
    });

    test('已规范的落点原样返回', () {
      const canonical =
          '{"ops":[{"insert":"事项一\\n","attributes":{"list":"unchecked"}}]}';
      expect(
        NoteMarkdownCodec.normalizeListAttributes(canonical),
        same(canonical),
      );
    });

    test('没有清单属性、空串、损坏 JSON 都原样返回', () {
      const plain = '{"ops":[{"insert":"正文\\n"}]}';
      expect(NoteMarkdownCodec.normalizeListAttributes(plain), same(plain));
      expect(NoteMarkdownCodec.normalizeListAttributes(''), '');
      expect(NoteMarkdownCodec.normalizeListAttributes('not-json'), 'not-json');
    });

    test('后面不是裸行尾时不合并', () {
      const odd =
          '{"ops":[{"insert":"事项一","attributes":{"list":"unchecked"}},'
          '{"insert":"续写\\n"}]}';
      expect(NoteMarkdownCodec.normalizeListAttributes(odd), same(odd));
    });
  });
}
