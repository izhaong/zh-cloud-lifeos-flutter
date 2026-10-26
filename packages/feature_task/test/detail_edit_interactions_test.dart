import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「真编辑」交互链路强断言（补测）。
///
/// 详情面板 `ReminderDetailPane` 是当前唯一可编辑提醒的 UI：
/// 标题 / 备注 / 标签 / 旗标 / 优先级 / 重复+结束日期 / 移动列表 / 子任务，
/// 保存 = copyWith 全量回写 `upsertItem`。
///
/// 与 `ui_walkthrough_test.dart` 的软断言（key 不存在时 if 跳过）不同，
/// 本文件每条断言都强校验：字段确实编辑、保存确实回写、链路闭环。
///
/// TC-UI-207（列表编辑页）仍是占位 SnackBar：真编辑页未落地，断言锁占位。
Future<void> _pump(
  WidgetTester tester,
  ReminderRepository repo, {
  String? openListId,
  String? selectedItemId,
  Size size = const Size(1366, 1024),
}) async {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: TaskScaffold(
          openListId: openListId ?? 'list.personal',
          selectedItemId: selectedItemId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<InMemoryReminderRepository> _seed() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(
    id: 'list.personal',
    title: '提醒事项',
    colorArgb: 0xFFFF9500,
  ));
  await repo.upsertList(const ReminderList(
    id: 'list.work',
    title: '工作',
    colorArgb: 0xFF007AFF,
  ));
  await repo.upsertItem(const ReminderItem(
    id: 'i1',
    listId: 'list.personal',
    title: '有备注的条目',
    notes: null,
    tags: [],
  ));
  return repo;
}

/// 详情面板 AppBar 上的「完成」保存按钮（避开首页智能卡同名文本）。
final _saveButton = find.descendant(
  of: find.byType(AppBar),
  matching: find.widgetWithText(TextButton, '完成'),
);

void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  // ── TC-UI-113a：详情编辑备注 → 保存 → 仓库 notes 回写 ──
  testWidgets('TC-UI-113a 详情编辑备注→保存→仓库 notes 回写', (tester) async {
    final repo = await _seed();
    await _pump(tester, repo, selectedItemId: 'i1');

    // 详情面板打开，含备注输入框（hint=备注）
    expect(find.text('详细信息'), findsOneWidget);
    final notesField = find.widgetWithText(TextField, '备注');
    expect(notesField, findsOneWidget, reason: '详情面板必须有备注输入框');

    await tester.enterText(notesField, '重要会议备注');
    await tester.pumpAndSettle();
    await tester.tap(_saveButton);
    await tester.pumpAndSettle();

    final all = await repo.watchItems().first;
    final saved = all.singleWhere((e) => e.id == 'i1');
    expect(saved.notes, '重要会议备注',
        reason: 'TC-UI-113a: 保存后备注必须回写仓库');
  });

  // ── TC-UI-113b：多字段一次编辑 → 保存 → 逐字段强断言 ──
  testWidgets('TC-UI-113b 多字段一次编辑→保存→仓库逐字段回写', (tester) async {
    final repo = await _seed();
    await _pump(tester, repo, selectedItemId: 'i1');

    expect(find.text('详细信息'), findsOneWidget);

    // 标题
    await tester.enterText(
      find.widgetWithText(TextField, '标题'),
      '改过的标题',
    );
    // 备注
    await tester.enterText(
      find.widgetWithText(TextField, '备注'),
      '备注X',
    );
    // 标签（hint=如：工作, 设计）
    await tester.enterText(
      find.widgetWithText(TextField, '如：工作, 设计'),
      '工作, 设计',
    );
    await tester.pumpAndSettle();

    // 旗标开关 → 打开
    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();

    // 优先级 → 高 !!!
    final priority = find.byWidgetPredicate(
      (w) => w is PopupMenuButton<int>,
    );
    expect(priority, findsOneWidget, reason: '详情面板有优先级弹出菜单');
    await tester.tap(priority);
    await tester.pumpAndSettle();
    await tester.tap(find.text('高 !!!'));
    await tester.pumpAndSettle();

    // 保存
    await tester.tap(_saveButton);
    await tester.pumpAndSettle();

    final all = await repo.watchItems().first;
    final saved = all.singleWhere((e) => e.id == 'i1');
    expect(saved.title, '改过的标题', reason: '标题已回写');
    expect(saved.notes, '备注X', reason: '备注已回写');
    expect(saved.tags, ['工作', '设计'], reason: '标签已回写并按分隔符拆分');
    expect(saved.isFlagged, isTrue, reason: '旗标已回写');
    expect(saved.priority, 9, reason: '优先级已回写（高=9）');
  });

  // ── TC-UI-113c：备注可被搜索命中（宽屏 inspector 无 CloseButton，
  // 故不叠加编辑态，改从列表工具栏搜索预置备注，避免详情标题 TextField 干扰断言） ──
  testWidgets('TC-UI-113c 备注可被搜索命中', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(
      id: 'list.personal',
      title: '提醒事项',
      colorArgb: 0xFFFF9500,
    ));
    await repo.upsertItem(const ReminderItem(
      id: 'i1',
      listId: 'list.personal',
      title: '有备注的条目',
      notes: '重要会议备注',
    ));
    await repo.upsertItem(const ReminderItem(
      id: 'i2',
      listId: 'list.personal',
      title: '无关条目',
    ));
    await _pump(tester, repo); // 不设 selectedItemId → 不打开详情

    await tester.enterText(
      find.byKey(const ValueKey('toolbar_search')),
      '会议',
    );
    await tester.pumpAndSettle();
    expect(find.text('有备注的条目'), findsOneWidget,
        reason: 'TC-UI-113c: 备注匹配即命中');
    expect(find.text('无关条目'), findsNothing,
        reason: '未命中备注的条目被过滤');
  });

  // ── TC-UI-319：详情重复区结束日期行（强断言，非软断言） ──
  testWidgets('TC-UI-319 详情重复区出现结束日期行且默认永不', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(
      id: 'list.personal',
      title: '提醒事项',
      colorArgb: 0xFFFF9500,
    ));
    await repo.upsertItem(ReminderItem(
      id: 'r1',
      listId: 'list.personal',
      title: '重复条目',
      dueAt: DateTime.now(),
      recurrence: 'daily',
    ));
    await _pump(tester, repo, selectedItemId: 'r1');

    expect(find.text('详细信息'), findsOneWidget);
    expect(find.text('重复'), findsWidgets, reason: '详情有重复区');
    expect(find.byKey(const ValueKey('recurrence_until_row')), findsOneWidget,
        reason: 'TC-UI-319: 设置了重复必须出现结束日期行');
    expect(find.text('结束日期'), findsOneWidget);
    expect(find.text('永不'), findsWidgets, reason: '空=永不');
  });

  // ── TC-UI-207：列表编辑页占位锁定（真编辑页未落地） ──
  testWidgets('TC-UI-207 列表编辑入口=占位 SnackBar（真编辑页落地后需更新）',
      (tester) async {
    final repo = await _seed();
    // 首页（openListId=null）才渲染 _CompactPane 的编辑占位按钮
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(375, 812)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TaskScaffold()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home_edit_placeholder')));
    await tester.pump();
    expect(find.text('编辑列表 · 规划占位'), findsOneWidget,
        reason: 'TC-UI-207: 真编辑页未落地，当前为规划占位');
  });
}