import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-122 / #665（Apple 备忘录「格式 → 字号」逐段调整）：
/// 判据是四档真把 quill 的 `size` 写进 delta、且作用在**整段**而非几个选中字；
/// 「恢复默认」要能撤销。每条断言都先证属性在点之前不存在，避免恒真。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<quill.QuillController> openEditor(
    WidgetTester tester, {
    String text = '苹果官网',
    TextSelection selection = const TextSelection.collapsed(offset: 2),
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
        text,
        TextSelection.collapsed(offset: text.length),
      )
      ..updateSelection(selection, quill.ChangeSource.local);
    await tester.pumpAndSettle();
    return editor.controller;
  }

  Future<void> openFontSizeSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('note_editor_format')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_format_size')));
    await tester.pumpAndSettle();
  }

  String delta(quill.QuillController controller) =>
      jsonEncode(controller.document.toDelta().toJson());

  List<Map<String, dynamic>> ops(quill.QuillController controller) =>
      (jsonDecode(delta(controller)) as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> opFor(
    quill.QuillController controller,
    String text,
  ) =>
      ops(controller).firstWhere(
        (op) => op['insert'] is String && (op['insert'] as String).contains(text),
      );

  Object? sizeOf(Map<String, dynamic> op) =>
      (op['attributes'] as Map?)?['size'];

  testWidgets('二级面板列出四档与恢复默认', (tester) async {
    await openEditor(tester);
    await openFontSizeSheet(tester);

    expect(find.byKey(const Key('note_editor_font_size_sheet')), findsOneWidget);
    for (final key in const [
      'note_format_size_12',
      'note_format_size_16',
      'note_format_size_20',
      'note_format_size_26',
      'note_format_size_default',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: '缺 $key');
    }
    for (final label in const ['小', '中', '大', '特大', '恢复默认']) {
      expect(
        find.descendant(
          of: find.byKey(const Key('note_editor_font_size_sheet')),
          matching: find.textContaining(label),
        ),
        findsWidgets,
        reason: '缺「$label」档',
      );
    }
  });

  for (final tier in const {'小': 12, '中': 16, '大': 20, '特大': 26}.entries) {
    testWidgets('字号「${tier.key}」把 size=${tier.value} 写进整段', (tester) async {
      // 光标停在正文中间且**没有选区**：只改选中字的实现在这里会写不进任何属性。
      final controller = await openEditor(tester);
      expect(delta(controller), isNot(contains('"size"')),
          reason: '点之前不该已有字号属性');

      await openFontSizeSheet(tester);
      await tester.tap(find.byKey(ValueKey('note_format_size_${tier.value}')));
      await tester.pumpAndSettle();

      expect(sizeOf(opFor(controller, '苹果官网')), tier.value,
          reason: '「${tier.key}」必须把数值档写进整段而不是只写选区');
      expect(find.byKey(const Key('note_editor_font_size_sheet')), findsNothing,
          reason: '选完档位后二级面板要收起');
    });
  }

  testWidgets('恢复默认撤销 inline 字号，回到 #463 的全局默认', (tester) async {
    final controller = await openEditor(tester);
    await openFontSizeSheet(tester);
    await tester.tap(find.byKey(const ValueKey('note_format_size_26')));
    await tester.pumpAndSettle();
    expect(sizeOf(opFor(controller, '苹果官网')), 26,
        reason: '先确证字号真的写进去了，否则「撤销」断言恒真');

    await openFontSizeSheet(tester);
    await tester.tap(find.byKey(const ValueKey('note_format_size_default')));
    await tester.pumpAndSettle();

    expect(delta(controller), isNot(contains('"size"')),
        reason: '「恢复默认」必须清掉 inline size 属性');
  });

  testWidgets('逐段：只给光标所在段写字号，不误伤相邻段', (tester) async {
    // '甲\n乙\n'：光标折在第二段段首（offset 2），第一段不该被改。
    final controller = await openEditor(
      tester,
      text: '甲\n乙',
      selection: const TextSelection.collapsed(offset: 2),
    );
    expect(sizeOf(opFor(controller, '甲')), isNull);
    expect(sizeOf(opFor(controller, '乙')), isNull);

    await openFontSizeSheet(tester);
    await tester.tap(find.byKey(const ValueKey('note_format_size_20')));
    await tester.pumpAndSettle();

    expect(sizeOf(opFor(controller, '甲')), isNull,
        reason: 'Apple 是逐段改字号，上一段不能被波及');
    expect(sizeOf(opFor(controller, '乙')), 20,
        reason: '光标所在段整段都要拿到新字号');
  });

  testWidgets('窄屏（375）主菜单不溢出，字号二级面板可达', (tester) async {
    await openEditor(tester, size: const Size(375, 800));

    await tester.tap(find.byKey(const ValueKey('note_editor_format')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '动作表不能 RenderFlex 溢出');
    await tester.tap(find.byKey(const ValueKey('note_format_size')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note_editor_font_size_sheet')), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '二级面板同样不能被窄屏压溢出');
  });
}
