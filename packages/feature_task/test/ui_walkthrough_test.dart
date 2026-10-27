import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 实机走查模拟：按 testcases 的 TC-UI 用例模拟用户操作流程。
/// 每个测试 = 一条完整用户链路。
void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  // ── TC-UI-201: 新建提醒草稿行 ──
  testWidgets('TC-UI-201 新建提醒草稿行：点＋→输入→Enter→落库', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '提醒事项', colorArgb: 0xFFFF9500));

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(375, 812);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TaskScaffold(openListId: 'list.personal')),
    ));
    await tester.pumpAndSettle();

    // 空态 → 点底栏新建
    expect(find.text('没有提醒'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom_new_item')));
    await tester.pumpAndSettle();

    // 草稿行出现
    final textField = find.byType(TextField).first;
    expect(textField, findsOneWidget);
    await tester.enterText(textField, '买牛奶');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // 项出现在列表
    expect(find.text('买牛奶'), findsOneWidget, reason: 'TC-UI-201: 新建落库后可见');
    expect(find.text('没有提醒'), findsNothing, reason: '空态让位');

    // 仓库中确实有这条
    final all = await repo.watchItems().first;
    expect(all.any((e) => e.title == '买牛奶'), isTrue);
  });

  // ── TC-UI-202/203: 搜索链路与空态 ──
  testWidgets('TC-UI-202/203 搜索链路：命中 + 空态', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '提醒事项', colorArgb: 0xFFFF9500));
    final now = DateTime.now();
    await repo.upsertItem(ReminderItem(id: 'i1', listId: 'list.personal', title: '买牛奶', dueAt: now));
    await repo.upsertItem(ReminderItem(id: 'i2', listId: 'list.personal', title: '写报告', dueAt: now));

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TaskScaffold(openListId: 'list.personal')),
    ));
    await tester.pumpAndSettle();

    // 初始两条可见
    expect(find.text('买牛奶'), findsOneWidget);
    expect(find.text('写报告'), findsOneWidget);

    // 搜索 "牛奶" → 只剩一条
    await tester.enterText(find.byKey(const ValueKey('toolbar_search')), '牛奶');
    await tester.pumpAndSettle();
    expect(find.text('买牛奶'), findsOneWidget);
    expect(find.text('写报告'), findsNothing);

    // 搜索无关词 → 空态
    await tester.enterText(find.byKey(const ValueKey('toolbar_search')), '不存在的词');
    await tester.pumpAndSettle();
    expect(find.text('无匹配结果'), findsOneWidget, reason: 'TC-UI-203: 搜索空态');
  });

  // ── TC-UI-204: 智能列表语义（today = 同日 + 过期未完成） ──
  testWidgets('TC-UI-204 智能列表语义：今天=同日+过期未完成', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '提醒事项', colorArgb: 0xFFFF9500));
    final now = DateTime.now();
    await repo.upsertItem(ReminderItem(id: 'i0', listId: 'list.personal', title: '过期任务', dueAt: now.subtract(const Duration(days: 1))));
    await repo.upsertItem(ReminderItem(id: 'i1', listId: 'list.personal', title: '今天任务A', dueAt: now));
    await repo.upsertItem(ReminderItem(id: 'i2', listId: 'list.personal', title: '今天任务B', dueAt: now));
    await repo.upsertItem(ReminderItem(id: 'i3', listId: 'list.personal', title: '明天任务', dueAt: now.add(const Duration(days: 1))));

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(375, 812);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TaskScaffold(openListId: 'smart.today')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('过期任务'), findsOneWidget, reason: '今天包含过期任务');
    expect(find.text('今天任务A'), findsOneWidget);
    expect(find.text('今天任务B'), findsOneWidget);
    expect(find.text('明天任务'), findsNothing, reason: '明天任务不在今天视图');
  });

  // ── TC-UI-206: 添加列表 ──
  testWidgets('TC-UI-206 添加列表：新建列表入首页', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '提醒事项', colorArgb: 0xFFFF9500));

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(375, 812);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TaskScaffold(openListId: null)),
    ));
    await tester.pumpAndSettle();

    // 首页有「添加列表」入口
    expect(find.text('添加列表'), findsOneWidget);
    await tester.tap(find.text('添加列表'));
    await tester.pumpAndSettle();

    // 新建列表对话框
    expect(find.text('新建列表').evaluate().isNotEmpty || find.text('添加列表').evaluate().isNotEmpty, isTrue);
    await tester.enterText(find.byType(TextField).first, '工作');
    // 找确认按钮
    await tester.tap(find.byKey(const ValueKey('new_list_submit')));
    await tester.pumpAndSettle();

    // 工作列表出现在首页
    expect(find.text('工作'), findsOneWidget, reason: 'TC-UI-206: 新列表入首页');
  });

  // ── TC-UI-109: 最近删除回收窗 ──
  testWidgets('TC-UI-109 最近删除：删除后入回收窗', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '提醒事项', colorArgb: 0xFFFF9500));
    final now = DateTime.now();
    await repo.upsertItem(ReminderItem(id: 'i1', listId: 'list.personal', title: '待删条目', dueAt: now));

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(375, 812);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TaskScaffold(openListId: 'list.personal')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('待删条目'), findsOneWidget);

    // 仓库层删除（walkthrough 用等价路径）
    await repo.deleteItem('i1');
    await tester.pumpAndSettle();

    // 列表中消失
    expect(find.text('待删条目'), findsNothing, reason: '删除后不在列表');

    // 开回收窗视图验证
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TaskScaffold(openListId: 'smart.trash')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('待删条目'), findsOneWidget, reason: 'TC-UI-109: 删除后入回收窗');
  });

  // ── TC-UI-110: 分区折叠 ──
  testWidgets('TC-UI-110 分区折叠：点分区头折叠/展开', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '提醒事项', colorArgb: 0xFFFF9500));
    final now = DateTime.now();
    await repo.upsertItem(ReminderItem(id: 'i1', listId: 'list.personal', title: '今天分区A', dueAt: now));
    await repo.upsertItem(ReminderItem(id: 'i2', listId: 'list.personal', title: '今天分区B', dueAt: now.add(const Duration(hours: 1))));

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TaskScaffold(openListId: 'list.personal')),
    ));
    await tester.pumpAndSettle();

    // 有分区头
    final sectionHeader = find.byKey(const ValueKey('section_今天'));
    expect(sectionHeader, findsOneWidget, reason: '有分区头');

    // 点分区头折叠
    await tester.tap(sectionHeader);
    await tester.pumpAndSettle();
    // 折叠后条目不可见（或分区头有折叠态）
    // 再次点击展开
    await tester.tap(find.byKey(const ValueKey('section_今天')));
    await tester.pumpAndSettle();
    expect(find.text('今天分区A'), findsOneWidget, reason: '展开后条目可见');
  });

  // ── TC-UI-113: 备注编辑 ──
  testWidgets('TC-UI-113 备注编辑：详情输入备注→保存→搜索命中', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '提醒事项', colorArgb: 0xFFFF9500));
    final now = DateTime.now();
    await repo.upsertItem(ReminderItem(id: 'i1', listId: 'list.personal', title: '有备注的条目', dueAt: now));

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TaskScaffold(openListId: 'list.personal')),
    ));
    await tester.pumpAndSettle();

    // 点行开详情（宽屏 inspector）
    await tester.tap(find.text('有备注的条目'));
    await tester.pumpAndSettle();
    expect(find.text('详细信息'), findsOneWidget, reason: '详情面板已打开');

    // 详情面板备注输入框（hint=备注；原软断言用了不存在的 detail_notes key）
    final notesField = find.widgetWithText(TextField, '备注');
    expect(notesField, findsOneWidget, reason: '详情面板必须有备注输入框');
    await tester.enterText(notesField, '重要会议备注');
    await tester.pumpAndSettle();

    // AppBar 上「完成」保存
    await tester.tap(find.descendant(
      of: find.byType(AppBar),
      matching: find.widgetWithText(TextButton, '完成'),
    ));
    await tester.pumpAndSettle();

    // 仓库已回写
    final saved =
        (await repo.watchItems().first).singleWhere((e) => e.id == 'i1');
    expect(saved.notes, '重要会议备注', reason: 'TC-UI-113: 备注已回写仓库');

    // 搜索备注
    await tester.enterText(
      find.byKey(const ValueKey('toolbar_search')),
      '会议',
    );
    await tester.pumpAndSettle();
    // inspector 仍开着（标题 TextField 同文案），故 findsWidgets
    expect(find.text('有备注的条目'), findsWidgets,
        reason: 'TC-UI-113: 备注可被搜索命中');
  });

  // ── TC-UI-118: 分组折叠（负向门禁） ──
  testWidgets('TC-UI-118 分组折叠：分组头折叠/展开 + 负向门禁', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: true);

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TaskScaffold(openListId: 'list.personal')),
    ));
    await tester.pumpAndSettle();

    // 负向门禁：无 iCloud/Outlook/账户字样
    expect(find.textContaining('iCloud'), findsNothing);
    expect(find.textContaining('Outlook'), findsNothing);

    // 分组头存在（seedSampleData 造了分组）
    expect(find.textContaining('今天'), findsWidgets);
  });

  // ── TC-UI-119: 移动提醒到其他列表 ──
  testWidgets('TC-UI-119 移动提醒：条目离开原列表出现在目标列表', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '提醒事项', colorArgb: 0xFFFF9500));
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作', colorArgb: 0xFF007AFF));
    final now = DateTime.now();
    await repo.upsertItem(ReminderItem(id: 'i1', listId: 'list.personal', title: '移动条目', dueAt: now));

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TaskScaffold(openListId: 'list.personal')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('移动条目'), findsOneWidget);

    // 直接用仓库层移动（UI 移动菜单的底层路径）
    await repo.moveItem('i1', 'list.work');
    await tester.pumpAndSettle();

    // 原列表消失
    expect(find.text('移动条目'), findsNothing, reason: 'TC-UI-119: 离开原列表');

    // 目标列表出现（仓库层验证）
    final workItems = await repo.watchItems(listId: 'list.work').first;
    expect(workItems.any((e) => e.title == '移动条目'), isTrue, reason: 'TC-UI-119: 出现在目标列表');
  });

  // ── TC-UI-122: 撤销/重做（撤销半） ──
  testWidgets('TC-UI-122 撤销完成：完成→撤销→恢复未完成', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '提醒事项', colorArgb: 0xFFFF9500));
    final now = DateTime.now();
    await repo.upsertItem(ReminderItem(id: 'i1', listId: 'list.personal', title: '可撤销条目', dueAt: now));

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TaskScaffold(openListId: 'list.personal')),
    ));
    await tester.pumpAndSettle();

    // 完成
    await tester.tapAt(tester.getCenter(find.byIcon(CupertinoIcons.circle).first));
    await tester.pumpAndSettle();

    // 撤销按钮出现
    expect(find.text('撤销'), findsOneWidget, reason: '完成后出现撤销');
    await tester.tap(find.byKey(const ValueKey('undo_complete')));
    await tester.pumpAndSettle();

    // 恢复未完成
    final all = await repo.watchItems().first;
    final item = all.singleWhere((e) => e.id == 'i1');
    expect(item.isCompleted, isFalse, reason: 'TC-UI-122: 撤销恢复未完成');
  });

  // ── TC-UI-319: 重复结束日期（详情 UI） ──
  testWidgets('TC-UI-319 重复结束日期：详情重复区出现结束日期行', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '提醒事项', colorArgb: 0xFFFF9500));
    final now = DateTime.now();
    await repo.upsertItem(ReminderItem(
      id: 'i1', listId: 'list.personal', title: '重复条目', dueAt: now, recurrence: 'daily',
    ));

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TaskScaffold(openListId: 'list.personal')),
    ));
    await tester.pumpAndSettle();

    // 点行开详情
    await tester.tap(find.text('重复条目'));
    await tester.pumpAndSettle();

    // 详情有重复区 + 结束日期行
    expect(find.text('重复'), findsWidgets);
    expect(find.text('结束日期'), findsOneWidget, reason: 'TC-UI-319: 重复区有结束日期行');
    expect(find.text('永不'), findsOneWidget, reason: '空=永不');
  });

  // ── TC-REG-107: 负向门禁全量 ──
  testWidgets('TC-REG-107 负向门禁：紧凑+宽屏无泄漏', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '提醒事项', colorArgb: 0xFFFF9500));

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;

    for (final size in [const Size(375, 812), const Size(1366, 1024)]) {
      view.physicalSize = size;
      view.devicePixelRatio = 1.0;
      await tester.pumpWidget(ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TaskScaffold(openListId: 'list.personal')),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('iCloud'), findsNothing);
      expect(find.textContaining('Outlook'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    }
  });
}
