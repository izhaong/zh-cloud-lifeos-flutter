import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-103/104/114：清单勾选、置顶排序、删除/恢复（F-06）。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  const checklistDelta =
      '{"ops":[{"insert":"事项一","attributes":{"list":"unchecked"}},{"insert":"\\n"},'
      '{"insert":"事项二","attributes":{"list":"unchecked"}},{"insert":"\\n"}]}';

  Future<InMemoryNoteRepository> pumpApp(WidgetTester tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    return repo;
  }

  Future<void> pumpScaffold(
    WidgetTester tester,
    InMemoryNoteRepository repo,
  ) async {
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

  // TC-NOTE-UI-103：加两条清单勾一条 → checklistDone=1
  testWidgets('清单勾选写入 checklistDone', (tester) async {
    final repo = await pumpApp(tester);
    await repo.upsertNote(
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: '购物',
        bodyDelta: checklistDelta,
      ),
    );
    await pumpScaffold(tester, repo);

    await tester.tap(find.text('购物'));
    await tester.pumpAndSettle();

    // #237：清单行内单次渲染——两条勾选行各有一个 quill 行内勾选框，
    // 不再有把同一份清单另列一遍的镜像面板（所以这里也不该再有 CupertinoCheckbox）。
    expect(find.byType(quill.QuillCheckboxPoint), findsNWidgets(2));
    expect(
      find.byType(CupertinoCheckbox),
      findsNothing,
      reason: '镜像清单面板已移除（#237）',
    );
    await tester.tap(find.byType(quill.QuillCheckboxPoint).at(1));
    await tester.pumpAndSettle();
    // #390：不再有「保存」按钮——输入后等去抖窗口过去即自动落库
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final note = (await repo.watchNotes().first).single;
    expect(note.checklistTotal, 2);
    expect(note.checklistDone, 1);
  });

  // TC-NOTE-UI-104：置顶排在未置顶前
  testWidgets('置顶后排到最前', (tester) async {
    final repo = await pumpApp(tester);
    await repo.upsertNote(
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: '第一条',
        bodyDelta: '{"ops":[{"insert":"a\\n"}]}',
      ),
    );
    await repo.upsertNote(
      const Note(
        id: 'n2',
        folderId: 'f1',
        title: '第二条',
        bodyDelta: '{"ops":[{"insert":"b\\n"}]}',
      ),
    );
    await pumpScaffold(tester, repo);
    expect(
      tester.getTopLeft(find.text('第一条')).dy,
      lessThan(tester.getTopLeft(find.text('第二条')).dy),
    );

    await tester.tap(find.text('第二条'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_pin_n2')));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('第二条')).dy,
      lessThan(tester.getTopLeft(find.text('第一条')).dy),
    );
  });

  // TC-NOTE-UI-114：删除进最近删除，可恢复
  testWidgets('删除进最近删除并可恢复', (tester) async {
    final repo = await pumpApp(tester);
    await repo.upsertNote(
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: '待删',
        bodyDelta: '{"ops":[{"insert":"x\\n"}]}',
      ),
    );
    await pumpScaffold(tester, repo);

    await tester.tap(find.text('待删'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_delete_n1')));
    await tester.pumpAndSettle();
    expect(find.text('待删'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('note_recycle')));
    await tester.pumpAndSettle();
    expect(find.text('最近删除'), findsOneWidget);
    expect(find.text('待删'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note_restore_n1')));
    await tester.pumpAndSettle();
    expect(find.text('待删'), findsNothing, reason: '回收列表已恢复，条目消失');

    final alive = await repo.watchNotes().first;
    expect(alive.single.id, 'n1');
    expect(alive.single.deletedAt, isNull);
  });
}
