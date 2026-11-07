import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// parity#420（矩阵 N02/N05）：Apple 把格式能力收在「格式」菜单里，本仓此前只有
/// 平铺按钮、没有这个入口 ⇒ 能力存在但找不到，且窄屏放不下。
///
/// 判据两半：入口必须存在且能到达**已实现**的能力（点「加粗」要真的改 delta）；
/// 未实现的能力不许摆成占位——那是 #444 判过的死控件形态。
/// #664 起标题样式/删除线/对齐/有序列表已接线（见 note_format_advanced_test.dart），
/// #665 起字号也已接线（见 note_font_size_test.dart）；仍未实现的只剩
/// 表格（矩阵 N04 后置）与画笔（N08 范围外）。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<quill.QuillController> openEditor(
    WidgetTester tester, {
    Size size = const Size(900, 900),
  }) async {
    final repo = InMemoryNoteRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = size
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
    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    editor.controller
      ..replaceText(
        0,
        0,
        '苹果官网',
        const TextSelection.collapsed(offset: 4),
      )
      ..updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 4),
        quill.ChangeSource.local,
      );
    await tester.pumpAndSettle();
    return editor.controller;
  }

  Future<void> openFormatMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('note_editor_format')));
    await tester.pumpAndSettle();
  }

  testWidgets('工具栏有「格式」入口，菜单列出已实现的能力', (tester) async {
    await openEditor(tester);
    await openFormatMenu(tester);

    expect(find.byKey(const Key('note_editor_format_sheet')), findsOneWidget);
    for (final key in const [
      'note_format_bold',
      'note_format_italic',
      'note_format_underline',
      'note_format_link',
      'note_format_checklist',
      // #664：新增四项，均已在 note_format_advanced_test.dart 断言真的改 delta
      'note_format_heading',
      'note_format_strike',
      'note_format_align',
      'note_format_ordered_list',
      // #665：字号二级面板入口
      'note_format_size',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: '缺 $key');
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('note_editor_format_sheet')),
        matching: find.text('字号'),
      ),
      findsOneWidget,
      reason: 'Apple 格式菜单的字号入口必须能找到',
    );
  });

  testWidgets('菜单不摆未实现能力的占位项', (tester) async {
    await openEditor(tester);
    await openFormatMenu(tester);
    // 先证菜单真的在：否则「找不到占位项」会因为整张菜单没弹而恒真。
    expect(find.byKey(const Key('note_editor_format_sheet')), findsOneWidget);

    for (final label in const ['表格', '画笔']) {
      expect(
        find.descendant(
          of: find.byKey(const Key('note_editor_format_sheet')),
          matching: find.text(label),
        ),
        findsNothing,
        reason: '「$label」能力尚未实现，摆进菜单就是死控件',
      );
    }
  });

  testWidgets('菜单里的「加粗」真的作用到选区', (tester) async {
    final controller = await openEditor(tester);
    final before = jsonEncode(controller.document.toDelta().toJson());
    expect(
      before,
      isNot(contains('"bold"')),
      reason: '点之前不该已有粗体属性（否则断言恒真）',
    );

    await openFormatMenu(tester);
    await tester.tap(find.byKey(const ValueKey('note_format_bold')));
    await tester.pumpAndSettle();

    expect(
      jsonEncode(controller.document.toDelta().toJson()),
      contains('"bold":true'),
      reason: '菜单项必须接线到 formatSelection，而不是只关个弹窗',
    );
    expect(
      find.byKey(const Key('note_editor_format_sheet')),
      findsNothing,
      reason: '选完能力后菜单要收起',
    );
  });

  testWidgets('窄屏（375）「格式」入口存在且能打开菜单', (tester) async {
    await openEditor(tester, size: const Size(375, 800));

    expect(find.byKey(const ValueKey('note_editor_format')), findsOneWidget);
    await openFormatMenu(tester);
    expect(find.byKey(const Key('note_editor_format_sheet')), findsOneWidget);
  });
}
