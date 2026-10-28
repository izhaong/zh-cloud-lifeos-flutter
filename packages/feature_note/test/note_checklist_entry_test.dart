import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// parity#202：编辑器要有「清单」入口，把普通行变成可勾选 To-Do 行，
/// 勾选后 `checklistDone` 才可能为 1（矩阵 N03 对等 / TC-NOTE-UI-103）。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('工具条「清单」把当前行转成勾选行，勾选后 checklistDone=1', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
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
    await tester.enterText(
      find.byKey(const ValueKey('note_editor_title')),
      '清单测试',
    );

    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    final controller = editor.controller;
    controller.replaceText(
      0,
      0,
      '买菜\n米饭',
      const TextSelection.collapsed(offset: 2),
    );
    // 选中第一行
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 2),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note_editor_checklist')));
    await tester.pumpAndSettle();

    expect(
      jsonEncode(controller.document.toDelta().toJson()),
      contains('"list":"unchecked"'),
      reason: '点「清单」后该行必须带 list 属性',
    );
    expect(
      find.byType(CupertinoCheckbox),
      findsWidgets,
      reason: '清单面板要出现勾选框',
    );

    await tester.tap(find.byKey(const ValueKey('note_editor_save')));
    await tester.pumpAndSettle();
    var note = (await repo.watchNotes().first).single;
    expect(note.checklistDone, 0);

    // 再进编辑器勾选第一条
    await tester.tap(find.text('清单测试'));
    await tester.pumpAndSettle();
    final editor2 = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    final controller2 = editor2.controller;
    final firstLine = controller2.document.toPlainText().split('\n').first;
    controller2.formatText(
      0,
      firstLine.length,
      quill.Attribute.clone(quill.Attribute.list, 'checked'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_editor_save')));
    await tester.pumpAndSettle();

    note = (await repo.watchNotes().first).single;
    expect(note.checklistDone, 1, reason: '勾选后清单计数应为 1');
  });
}
