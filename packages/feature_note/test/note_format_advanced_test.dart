import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-120 / #664（矩阵 N02 对等）：格式菜单补标题样式、删除线、对齐、
/// 有序列表。判据是「菜单项真的把 quill 属性写进 delta」，不是只看菜单弹出：
/// 每条断言都先证属性在点之前不存在，避免恒真。表格按矩阵 N04「后置」不做。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<quill.QuillController> openEditor(WidgetTester tester) async {
    final repo = InMemoryNoteRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
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
      ..replaceText(0, 0, '苹果官网', const TextSelection.collapsed(offset: 4))
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

  String delta(quill.QuillController controller) =>
      jsonEncode(controller.document.toDelta().toJson());

  testWidgets('删除线：菜单项把 strike 属性写进选区', (tester) async {
    final controller = await openEditor(tester);
    expect(
      delta(controller),
      isNot(contains('"strike"')),
      reason: '点之前不该已有删除线属性',
    );

    await openFormatMenu(tester);
    await tester.tap(find.byKey(const ValueKey('note_format_strike')));
    await tester.pumpAndSettle();

    expect(
      delta(controller),
      contains('"strike":true'),
      reason: '删除线必须落到 quill Attribute.strikeThrough',
    );
    expect(find.byKey(const Key('note_editor_format_sheet')), findsNothing);
  });

  testWidgets('有序列表：菜单项把 list=ordered 写进当前行', (tester) async {
    final controller = await openEditor(tester);
    expect(
      delta(controller),
      isNot(contains('ordered')),
      reason: '点之前不该已是有序列表',
    );

    await openFormatMenu(tester);
    await tester.tap(find.byKey(const ValueKey('note_format_ordered_list')));
    await tester.pumpAndSettle();

    expect(
      delta(controller),
      contains('"list":"ordered"'),
      reason: '有序列表必须落到 quill Attribute.ol',
    );
  });

  testWidgets('标题样式：二级面板能设 H2，也能回退正文', (tester) async {
    final controller = await openEditor(tester);
    expect(
      delta(controller),
      isNot(contains('"header"')),
      reason: '点之前不该已有标题属性',
    );

    await openFormatMenu(tester);
    await tester.tap(find.byKey(const ValueKey('note_format_heading')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note_editor_heading_sheet')), findsOneWidget);
    for (final key in const [
      'note_format_heading_body',
      'note_format_heading_1',
      'note_format_heading_2',
      'note_format_heading_3',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: '缺 $key');
    }

    await tester.tap(find.byKey(const ValueKey('note_format_heading_2')));
    await tester.pumpAndSettle();
    expect(
      delta(controller),
      contains('"header":2'),
      reason: '标题 2 必须落到 quill Attribute.h2',
    );

    // 反向对照：「正文」要把 header 撤销，否则二级面板只是单向死控件
    await openFormatMenu(tester);
    await tester.tap(find.byKey(const ValueKey('note_format_heading')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_format_heading_body')));
    await tester.pumpAndSettle();
    expect(
      delta(controller),
      isNot(contains('"header":2')),
      reason: '「正文」必须撤销 header 属性',
    );
  });

  testWidgets('对齐：二级面板能设居中与右对齐', (tester) async {
    final controller = await openEditor(tester);
    expect(
      delta(controller),
      isNot(contains('"align"')),
      reason: '点之前不该已有对齐属性',
    );

    await openFormatMenu(tester);
    await tester.tap(find.byKey(const ValueKey('note_format_align')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note_editor_align_sheet')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note_format_align_center')));
    await tester.pumpAndSettle();
    expect(
      delta(controller),
      contains('"align":"center"'),
      reason: '居中必须落到 quill Attribute.centerAlignment',
    );

    await openFormatMenu(tester);
    await tester.tap(find.byKey(const ValueKey('note_format_align')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_format_align_right')));
    await tester.pumpAndSettle();
    expect(
      delta(controller),
      contains('"align":"right"'),
      reason: '右对齐必须落到 quill Attribute.rightAlignment',
    );
  });

  testWidgets('窄屏（375）主菜单不因新增项而溢出，二级面板可达', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(375, 800)
      ..devicePixelRatio = 1.0;
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '备忘录'));
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

    await openFormatMenu(tester);
    expect(tester.takeException(), isNull, reason: '动作表不能 RenderFlex 溢出');
    await tester.tap(find.byKey(const ValueKey('note_format_align')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note_editor_align_sheet')), findsOneWidget);
  });
}
