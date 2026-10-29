import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #397 矩阵 N02/N05（TC-NOTE-UI-102）：编辑器要有斜体、下划线、链接三样能力，
/// 且 Markdown 编解码认识链接。金标准是 Apple 备忘录的 BIU + 添加链接。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<quill.QuillController> openEditor(
    WidgetTester tester,
    InMemoryNoteRepository repo,
  ) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;
    // 「新建」要先有文件夹可落（默认文件夹引导），否则点了不推编辑器。
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '备忘录'));
    // 先卸载上一轮的 ProviderScope：同类型元素被复用时容器与导航栈不重建，
    // 上一条用例留下的编辑器/弹层会让这一条找不到 note_new。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(const ValueKey('note_new')));
    await tester.pumpAndSettle();
    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    final controller = editor.controller;
    controller.replaceText(
      0,
      0,
      '苹果官网',
      const TextSelection.collapsed(offset: 4),
    );
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();
    return controller;
  }

  String deltaJson(quill.QuillController controller) =>
      jsonEncode(controller.document.toDelta().toJson());

  testWidgets('工具条「斜体」把选区标成 italic', (tester) async {
    final controller = await openEditor(tester, InMemoryNoteRepository());
    expect(
      deltaJson(controller),
      isNot(contains('"italic"')),
      reason: '点之前不该已有斜体属性（否则断言恒真）',
    );
    // #420：格式能力收进「格式」菜单，先开菜单再点能力项。
    await tester.tap(find.byKey(const ValueKey('note_editor_format')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_format_italic')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(
      deltaJson(controller),
      contains('"italic":true'),
      reason: '点「斜体」后选区必须带 italic 属性',
    );
  });

  testWidgets('工具条「下划线」把选区标成 underline', (tester) async {
    final controller = await openEditor(tester, InMemoryNoteRepository());
    // #420：格式能力收进「格式」菜单，先开菜单再点能力项。
    await tester.tap(find.byKey(const ValueKey('note_editor_format')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_format_underline')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(
      deltaJson(controller),
      contains('"underline":true'),
      reason: '点「下划线」后选区必须带 underline 属性',
    );
  });

  testWidgets('「链接」弹层写 URL → 选区带 link 属性并落库', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '备忘录'));
    final controller = await openEditor(tester, repo);

    // #420：格式能力收进「格式」菜单，先开菜单再点能力项。
    await tester.tap(find.byKey(const ValueKey('note_editor_format')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_format_link')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note_link_url')),
      findsOneWidget,
      reason: '点「链接」要出现输入 URL 的弹层',
    );
    await tester.enterText(
      find.byKey(const ValueKey('note_link_url')),
      'https://apple.com',
    );
    await tester.tap(find.byKey(const ValueKey('note_link_submit')));
    await tester.pumpAndSettle();

    expect(
      deltaJson(controller),
      contains('"link":"https://apple.com"'),
      reason: '确认后选区必须带上链接属性',
    );

    await tester.tap(find.byKey(const ValueKey('note_editor_save')));
    await tester.pumpAndSettle();
    final note = (await repo.watchNotes().first).single;
    expect(
      note.bodyDelta,
      contains('"link":"https://apple.com"'),
      reason: '链接要真的落库，而不只在当前会话内存里',
    );
  });

  testWidgets('没有选区时点「链接」只提示，不弹输入框（反向对照）', (tester) async {
    final controller = await openEditor(tester, InMemoryNoteRepository());
    controller.updateSelection(
      const TextSelection.collapsed(offset: 2),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    // #420：格式能力收进「格式」菜单，先开菜单再点能力项。
    await tester.tap(find.byKey(const ValueKey('note_editor_format')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_format_link')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(
      find.text('先选中要加链接的文字'),
      findsOneWidget,
      reason: '光标没选中文字时要当场说明原因，而不是静默无反应',
    );
    expect(
      find.byKey(const ValueKey('note_link_url')),
      findsNothing,
      reason: '不可用时不该弹出输入框让人白填一次 URL',
    );
    expect(
      deltaJson(controller),
      isNot(contains('"link"')),
      reason: '无所选时绝不写链接属性',
    );
  });

  testWidgets('紧凑宽度（375）打开编辑器不因工具条溢出抛异常', (tester) async {
    final repo = InMemoryNoteRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(375, 844)
      ..devicePixelRatio = 1.0;
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '备忘录'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(const ValueKey('note_new')));
    await tester.pumpAndSettle();
    // 溢出会以 RenderFlex 异常的形式冒出来；这里只要求「打得开、不抛」。
    expect(find.byType(quill.QuillEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Markdown 编解码认识链接', () {
    test('toMarkdown 把 link 属性写成 [文字](url)', () {
      final delta = jsonEncode({
        'ops': [
          {'insert': '看 '},
          {
            'insert': '官网',
            'attributes': {'link': 'https://apple.com'},
          },
          {'insert': ' 吧\n'},
        ],
      });
      final md = NoteMarkdownCodec.toMarkdown('标题', delta);
      expect(
        md,
        contains('看 [官网](https://apple.com) 吧'),
        reason: '链接必须在导出正文里可读',
      );
    });

    test('fromMarkdown 把 [文字](url) 解成带 link 的 op，行属性只落行尾 op', () {
      final parsed = NoteMarkdownCodec.fromMarkdown(
        '# 标题\n'
        '看 [官网](https://apple.com) 吧\n',
      );
      expect(parsed.title, '标题');
      final ops = (jsonDecode(parsed.deltaJson) as Map)['ops'] as List;
      final linkOps = ops
          .whereType<Map>()
          .where((o) => (o['attributes'] as Map?)?['link'] != null)
          .toList();
      expect(linkOps.length, 1);
      expect(linkOps.single['insert'], '官网');
      expect(
        (linkOps.single['attributes'] as Map)['link'],
        'https://apple.com',
      );
      // 行属性与行内属性不能挤在同一个 op 上（quill 规范落点）
      for (final op in ops.whereType<Map>()) {
        final insert = op['insert'];
        final attrs = op['attributes'];
        if (insert is String && insert.contains('\n')) {
          expect(
            (attrs as Map?)?['link'],
            isNull,
            reason: '含换行的 op 不该再带行内 link，否则 quill 断言行属性冲突',
          );
        }
      }
      expect(
        () => quill.Document.fromJson(
          (jsonDecode(parsed.deltaJson) as Map)['ops'] as List,
        ),
        returnsNormally,
        reason: '解出来的 Delta 必须是 quill 认的合法落点',
      );
    });

    test('清单行的链接：link 落在文字 op、list 落在行尾 op', () {
      final parsed = NoteMarkdownCodec.fromMarkdown(
        '- [ ] 看 [官网](https://apple.com)\n',
      );
      final ops = (jsonDecode(parsed.deltaJson) as Map)['ops'] as List;
      final joined = ops
          .whereType<Map>()
          .map((o) => '${o['insert']}@${(o['attributes'] as Map?)?.keys.join(',')}')
          .join(' | ');
      expect(
        ops.any((o) => (o['attributes'] as Map?)?['link'] != null),
        isTrue,
        reason: '清单行里的链接也得带 link 属性：$joined',
      );
      final lineOp = ops.lastWhere(
        (o) => o['insert'] is String && (o['insert'] as String).contains('\n'),
      );
      expect(
        (lineOp['attributes'] as Map?)?['list'],
        'unchecked',
        reason: '行属性必须挂在含换行的那个 op 上：$joined',
      );
    });

    test('没有链接的正文不会凭空多出 link（反向对照）', () {
      final parsed = NoteMarkdownCodec.fromMarkdown('# 标题\n普通一行\n');
      expect(parsed.deltaJson, isNot(contains('link')));
    });
  });
}
