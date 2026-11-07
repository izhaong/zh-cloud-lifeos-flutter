import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #678 文字颜色 / #679 高亮颜色 / #680 缩进增减（Apple 备忘录格式菜单对等）。
/// 判据是属性真写进 delta、且「恢复默认」能撤销；每条先证点之前属性不存在。
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
    TextSelection selection = const TextSelection(baseOffset: 0, extentOffset: 2),
  }) async {
    final repo = InMemoryNoteRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 1400)
      ..devicePixelRatio = 1.0;
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
    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    editor.controller
      ..replaceText(0, 0, text, TextSelection.collapsed(offset: text.length))
      ..updateSelection(selection, quill.ChangeSource.local);
    await tester.pumpAndSettle();
    return editor.controller;
  }

  Future<void> tapFormat(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(const ValueKey('note_editor_format')));
    await tester.pumpAndSettle();
    final item = find.byKey(ValueKey(key));
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  Future<void> tapSheetItem(WidgetTester tester, String key) async {
    final item = find.byKey(ValueKey(key));
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  List<Map<String, dynamic>> ops(quill.QuillController c) =>
      (jsonDecode(jsonEncode(c.document.toDelta().toJson())) as List)
          .cast<Map<String, dynamic>>();

  Object? attrOn(quill.QuillController c, String text, String attr) {
    final op = ops(c).firstWhere(
      (op) => op['insert'] is String && (op['insert'] as String).contains(text),
    );
    return (op['attributes'] as Map?)?[attr];
  }

  testWidgets('格式菜单列出文字颜色、高亮颜色与缩进增减', (tester) async {
    await openEditor(tester);
    await tester.tap(find.byKey(const ValueKey('note_editor_format')));
    await tester.pumpAndSettle();
    for (final key in const [
      'note_format_text_color',
      'note_format_highlight',
      'note_format_indent_increase',
      'note_format_indent_decrease',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: '缺 $key');
    }
  });

  testWidgets('#678 文字颜色：选中「苹果」设红色写 color，恢复默认撤销', (tester) async {
    final c = await openEditor(tester);
    expect(attrOn(c, '苹果', 'color'), isNull, reason: '点之前不该有颜色');

    await tapFormat(tester, 'note_format_text_color');
    expect(find.byKey(const Key('note_editor_text_color_sheet')), findsOneWidget);
    await tapSheetItem(tester, 'note_text_color_red');
    expect(attrOn(c, '苹果', 'color'), '#FF3B30');
    expect(attrOn(c, '官网', 'color'), isNull, reason: '只改选中的字');

    c.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 2),
      quill.ChangeSource.local,
    );
    await tapFormat(tester, 'note_format_text_color');
    await tapSheetItem(tester, 'note_text_color_default');
    expect(attrOn(c, '苹果', 'color'), isNull);
  });

  testWidgets('#679 高亮颜色：选中「苹果」设黄写 background，恢复默认撤销', (tester) async {
    final c = await openEditor(tester);
    expect(attrOn(c, '苹果', 'background'), isNull);

    await tapFormat(tester, 'note_format_highlight');
    expect(find.byKey(const Key('note_editor_highlight_sheet')), findsOneWidget);
    await tapSheetItem(tester, 'note_highlight_yellow');
    expect(attrOn(c, '苹果', 'background'), '#FFE58F');
    expect(attrOn(c, '官网', 'background'), isNull);

    c.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 2),
      quill.ChangeSource.local,
    );
    await tapFormat(tester, 'note_format_highlight');
    await tapSheetItem(tester, 'note_highlight_default');
    expect(attrOn(c, '苹果', 'background'), isNull);
  });

  testWidgets('#680 增加缩进写 indent=1，再增为 2，减少两次回到无缩进', (tester) async {
    final c = await openEditor(
      tester,
      selection: const TextSelection.collapsed(offset: 2),
    );
    Object? indent() => attrOn(c, '\n', 'indent');
    expect(indent(), isNull);

    await tapFormat(tester, 'note_format_indent_increase');
    expect(indent(), 1);
    await tapFormat(tester, 'note_format_indent_increase');
    expect(indent(), 2);
    await tapFormat(tester, 'note_format_indent_decrease');
    expect(indent(), 1);
    await tapFormat(tester, 'note_format_indent_decrease');
    expect(indent(), isNull);
  });
}
