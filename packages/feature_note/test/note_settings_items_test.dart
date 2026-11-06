import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-111 / #392：设置页要像 Apple 备忘录那样摆出「新备忘录开头格式」
/// （弹出菜单）与「按日期分组备忘录」（勾选框），并且两把都有真实消费者——
/// 分组闸驱动列表相对日期节头，开头格式驱动新建备忘录的光标与正文。
///
/// #659 起节头写「今天 / 昨天 / 本周 / 更早」，与行内日期文案同名，所以两类
/// 判据都按 Key 数：`note_group_*` 是节头、`note_row_date_*` 是行内日期。
/// 固定时钟到 2026-04-10，让两条夹具分别落「本周 / 更早」两个桶。
///
/// 每条都配反向对照：断「关掉了就没了」之前先证「开着时有」，否则判据恒真。
void main() {
  // 只认四个真实分桶；设置页勾选框的 `note_group_by_date` 不能算节头。
  const groupKeys = <String>[
    'note_group_today',
    'note_group_yesterday',
    'note_group_thisWeek',
    'note_group_earlier',
  ];
  final groupHeader = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        groupKeys.contains((w.key as ValueKey<String>).value),
  );
  final rowDate = find.byWidgetPredicate(
    (w) =>
        w is Text &&
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('note_row_date_') &&
        RegExp(
          r'^(今天|昨天|星期[一二三四五六日]|\d{1,2}月\d{1,2}日|\d{4}年\d{1,2}月\d{1,2}日)$',
        ).hasMatch(w.data ?? ''),
  );

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<InMemoryNoteRepository> seededRepo() async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '备忘录'));
    await repo.upsertNote(
      Note(
        id: 'n1',
        folderId: 'f1',
        title: '去年的',
        bodyDelta: '{"ops":[{"insert":"去年正文\\n"}]}',
        clientUpdatedAt: DateTime(2025, 3, 5).millisecondsSinceEpoch,
      ),
    );
    await repo.upsertNote(
      Note(
        id: 'n2',
        folderId: 'f1',
        title: '今年的',
        bodyDelta: '{"ops":[{"insert":"今年正文\\n"}]}',
        clientUpdatedAt: DateTime(2026, 4, 6).millisecondsSinceEpoch,
      ),
    );
    return repo;
  }

  Future<void> pump(WidgetTester tester, InMemoryNoteRepository repo) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;
    // 先卸载上一轮的 ProviderScope：同类型元素被复用时容器与导航栈不重建，
    // 上一条用例留下的设置页/编辑器会让这一条找不到 note_new。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          // #659：分桶相对此刻，固定时钟才能让「本周 / 更早」两桶不随运行日漂移。
          noteClockProvider.overrideWithValue(() => DateTime(2026, 4, 10, 12)),
        ],
        child: const MaterialApp(
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('note_settings')));
    await tester.pumpAndSettle();
  }

  Future<void> backToList(WidgetTester tester) async {
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
  }

  /// 设置页里把「开头格式」选成 [optionKey]（Apple 的弹出菜单形态）。
  Future<void> chooseBeginWith(WidgetTester tester, String optionKey) async {
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('note_begin_with')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('note_begin_with_sheet')),
      findsOneWidget,
      reason: '没弹层的话点 $optionKey 只是在空树上找钥匙',
    );
    await tester.tap(find.byKey(ValueKey(optionKey)));
    await tester.pumpAndSettle();
    await backToList(tester);
  }

  quill.QuillController openNewEditor(WidgetTester tester) {
    expect(
      find.byKey(const Key('note_editor_page')),
      findsOneWidget,
      reason: '没进编辑器就直接读 controller，读到的是上一屏的树',
    );
    return tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller;
  }

  /// 宽屏（#421）选中既有记录走的是第三栏内嵌宿主，不是推入页——
  /// 形状不同，判据一样：先证明编辑器真的在屏上，再读它的 controller。
  quill.QuillController embeddedEditor(WidgetTester tester) {
    expect(
      find.byKey(const Key('note_editor_embedded')),
      findsOneWidget,
      reason: '没落到内嵌栏就读 controller，读到的是列表那一侧的树',
    );
    return tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller;
  }

  Future<String> newNoteDelta(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('note_new')));
    await tester.pumpAndSettle();
    return jsonEncode(openNewEditor(tester).document.toDelta().toJson());
  }

  CupertinoCheckbox groupCheckbox(WidgetTester tester) =>
      tester.widget<CupertinoCheckbox>(
        find.descendant(
          of: find.byKey(const ValueKey('note_group_by_date')),
          matching: find.byType(CupertinoCheckbox),
        ),
      );

  String beginWithValueLabel(WidgetTester tester) {
    final labels = find.descendant(
      of: find.byKey(const ValueKey('note_begin_with')),
      matching: find.byType(Text),
    );
    expect(labels, findsOneWidget, reason: '入口文案唯一才量得到当前档');
    return tester.widget<Text>(labels).data ?? '';
  }

  testWidgets('设置页摆出开头格式（弹出菜单四档）与按日期分组（勾选框）', (
    tester,
  ) async {
    await pump(tester, await seededRepo());
    await openSettings(tester);

    expect(find.text('按日期分组备忘录'), findsOneWidget);
    expect(find.text('新备忘录开头格式'), findsOneWidget);
    // 形态核对：分组是勾选框（Apple 同款）而非开关；开头格式当前档可读。
    expect(groupCheckbox(tester).value, isTrue, reason: '默认分组，老用户不变');
    expect(find.byType(CupertinoSwitch), findsNothing);
    expect(beginWithValueLabel(tester), '无', reason: '默认档 = 现状的空白正文');

    await tester.tap(find.byKey(const ValueKey('note_begin_with')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('note_begin_with_sheet')),
      findsOneWidget,
      reason: '入口点了没弹层的话，下面四条断言全在空树上跑',
    );
    for (final option in const [
      'note_begin_with_nothing',
      'note_begin_with_title',
      'note_begin_with_body',
      'note_begin_with_checklist',
    ]) {
      expect(find.byKey(ValueKey(option)), findsOneWidget, reason: '缺档 $option');
    }
  });

  testWidgets('关掉「按日期分组备忘录」→ 日期节头消失、行内日期保留', (
    tester,
  ) async {
    await pump(tester, await seededRepo());
    // 开着时：夹具分别落「本周」「更早」两个桶，两行都带编辑日期。
    expect(groupHeader, findsNWidgets(2));
    expect(rowDate, findsNWidgets(2));

    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('note_group_by_date')));
    await tester.pumpAndSettle();
    expect(groupCheckbox(tester).value, isFalse);
    await backToList(tester);

    expect(groupHeader, findsNothing, reason: '勾选关掉后不该再画日期节头');
    expect(
      rowDate,
      findsNWidgets(2),
      reason: '只撤节头：行内编辑日期是 N12 的能力，不该被连带清掉',
    );

    // 再勾回来：节头重现（证明这把开关双向可达，不是只能关不能开）。
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('note_group_by_date')));
    await tester.pumpAndSettle();
    await backToList(tester);
    expect(groupHeader, findsNWidgets(2));
  });

  testWidgets('开头格式「待办」→ 新建备忘录正文以未勾选清单项开头', (
    tester,
  ) async {
    await pump(tester, await seededRepo());
    await chooseBeginWith(tester, 'note_begin_with_checklist');
    await openSettings(tester);
    expect(beginWithValueLabel(tester), '待办', reason: '选完的档位要读得回来');
    await backToList(tester);

    expect(
      await newNoteDelta(tester),
      contains('"list":"unchecked"'),
      reason: '选了待办，新建正文必须真的带一个未勾选清单项',
    );
  });

  testWidgets('开头格式「无」→ 新建备忘录正文仍然空白', (tester) async {
    await pump(tester, await seededRepo());
    await chooseBeginWith(tester, 'note_begin_with_nothing');

    final delta = await newNoteDelta(tester);
    expect(
      delta,
      isNot(contains('"list"')),
      reason: '「无」档必须保持老行为：正文不种清单',
    );
  });

  testWidgets('开头格式「标题」→ 新建备忘录焦点在标题框', (tester) async {
    await pump(tester, await seededRepo());
    await chooseBeginWith(tester, 'note_begin_with_title');

    await tester.tap(find.byKey(const ValueKey('note_new')));
    await tester.pumpAndSettle();
    final title = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('note_editor_title')),
    );
    final body = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    expect(title.focusNode?.hasFocus, isTrue, reason: '标题档要把光标交给标题');
    expect(body.focusNode.hasFocus, isFalse, reason: '同时只能有一个焦点');
  });

  testWidgets('开头格式「正文」→ 新建备忘录焦点在正文', (tester) async {
    await pump(tester, await seededRepo());
    await chooseBeginWith(tester, 'note_begin_with_body');

    await tester.tap(find.byKey(const ValueKey('note_new')));
    await tester.pumpAndSettle();
    final title = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('note_editor_title')),
    );
    final body = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    expect(body.focusNode.hasFocus, isTrue, reason: '正文档要把光标交给正文');
    expect(title.focusNode?.hasFocus ?? false, isFalse);
  });

  testWidgets('开头格式只作用于新建：编辑既有备忘录不重排正文', (tester) async {
    await pump(tester, await seededRepo());
    await chooseBeginWith(tester, 'note_begin_with_checklist');

    await tester.tap(find.text('去年的'));
    await tester.pumpAndSettle();
    final controller = embeddedEditor(tester);
    final delta = jsonEncode(controller.document.toDelta().toJson());
    expect(
      delta,
      isNot(contains('"list"')),
      reason: '存量正文不能被设置改写',
    );
    expect(
      controller.document.toPlainText(),
      contains('去年正文'),
      reason: '既有内容要原样读回',
    );
  });
}
