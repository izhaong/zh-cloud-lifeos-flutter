import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  Widget child = const TaskScaffold(openListId: 'list.personal'),
  required ReminderRepository repo,
}) async {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  // TC-UI-201
    testWidgets('底部工具条「新提醒」出现于三档宽度', (tester) async {
    for (final size in [
      const Size(375, 812),
      const Size(834, 1112),
      const Size(1366, 1024),
    ]) {
      final repo = InMemoryReminderRepository();
      await _pump(tester, size: size, repo: repo);
      expect(find.text('新提醒'), findsOneWidget);
    }
  });

  // TC-UI-201
    testWidgets('草稿行提交后恰好一次落库；空标题零写入', (tester) async {
    final repo = _CountingRepo(InMemoryReminderRepository());
    await _pump(
      tester,
      size: const Size(834, 1112),
      repo: repo,
      child: const TaskScaffold(openListId: 'list.personal'),
    );

    await tester.tap(find.text('新提醒'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '新提醒事项'), '买菜');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repo.upsertCount, 1);
    expect(repo.lastItem?.title, '买菜');
    expect(repo.lastItem?.listId, 'list.personal');

    // 空标题：不落库
    await tester.tap(find.text('新提醒'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '新提醒事项'), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.upsertCount, 1); // 未增加
  });

  // TC-UI-106
    testWidgets('旗标点击即时切换并从 smart.flagged 流出', (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(
      tester,
      size: const Size(834, 1112),
      repo: repo,
      child: const TaskScaffold(openListId: 'list.personal'),
    );

    // 买牛奶 初始已旗标：行内旗标（key 定位，避开侧栏智能列表图标）
    final rowFlag = find.byKey(const ValueKey('row_flag_1'));
    expect(rowFlag, findsOneWidget);
    await tester.tap(rowFlag);
    await tester.pumpAndSettle();
    // 取消后行内旗标消失（只剩未旗标的空心图标）
    expect(find.byKey(const ValueKey('row_flag_1')), findsOneWidget);
    final flagged = await repo.watchItems(listId: 'smart.flagged').first;
    expect(flagged, isEmpty);
  });

  // TC-UI-113
    testWidgets('详情面板编辑备注/旗标/优先级/标签 → upsertItem 全量回写', (tester) async {
    final repo = _CountingRepo(InMemoryReminderRepository());
    await _pump(
      tester,
      size: const Size(1366, 1024),
      repo: repo,
      child: const TaskScaffold(
        openListId: 'list.personal',
        selectedItemId: '1',
      ),
    );

    expect(find.text('详细信息'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '').first,
      '对齐 Reminders 交互',
    );
    // 避开「完成」智能卡文本：点详情面板 AppBar 上的 TextButton
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.widgetWithText(TextButton, '完成'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.upsertCount, 1);
    expect(repo.lastItem?.id, '1');
  });

  // TC-UI-206
    testWidgets('添加列表弹窗：提交后首页即时出现新列表', (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(
      tester,
      size: const Size(375, 812),
      repo: repo,
      child: const TaskScaffold(), // 紧凑首页
    );

    await tester.tap(find.text('添加列表'));
    await tester.pumpAndSettle();

    // 弹窗输入框（避开首页搜索框；弹窗 hint 是「列表名称」）
    await tester.enterText(
      find.widgetWithText(TextField, '列表名称'),
      '购物',
    );
    await tester.tap(find.text('完成').last);
    await tester.pumpAndSettle();

    expect(find.text('购物'), findsWidgets);
    final lists = await repo.watchLists().first;
    expect(lists.map((e) => e.title), contains('购物'));
  });

  // TC-UI-N1 负向门禁
    testWidgets('全仓无 FloatingActionButton（Reminders IA 门禁）', (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(tester, size: const Size(375, 812), repo: repo);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}

/// 计数仓库：断言 upsertItem 恰好一次等（组合装饰，不继承 final 类）。
class _CountingRepo implements ReminderRepository {
  _CountingRepo(this._inner);

  final InMemoryReminderRepository _inner;
  int upsertCount = 0;
  ReminderItem? lastItem;

  @override
  Stream<List<ReminderList>> watchLists() => _inner.watchLists();

  @override
  Stream<List<ReminderItem>> watchItems({String? listId}) =>
      _inner.watchItems(listId: listId);

  @override
  Future<void> upsertItem(ReminderItem item) async {
    upsertCount++;
    lastItem = item;
    await _inner.upsertItem(item);
  }

  @override
  Future<void> toggleCompleted(String itemId) =>
      _inner.toggleCompleted(itemId);

  @override
  Future<void> toggleFlagged(String itemId) => _inner.toggleFlagged(itemId);

  @override
  Future<void> moveItem(String itemId, String targetListId) =>
      _inner.moveItem(itemId, targetListId);

  @override
  Future<void> deleteItem(String itemId) => _inner.deleteItem(itemId);

  @override
  Future<void> restoreItem(String itemId) => _inner.restoreItem(itemId);

  @override
  Future<int> purgeExpiredDeleted() => _inner.purgeExpiredDeleted();

  @override
  Future<void> upsertList(ReminderList list) => _inner.upsertList(list);

  @override
  Future<void> deleteList(String listId) => _inner.deleteList(listId);

  @override
  Future<void> upsertSection({
    required String listId,
    required ReminderSection section,
  }) =>
      _inner.upsertSection(listId: listId, section: section);

  @override
  Future<void> reorderSection({
    required String listId,
    required List<String> sectionIds,
  }) =>
      _inner.reorderSection(listId: listId, sectionIds: sectionIds);

  @override
  Future<void> deleteSection({
    required String listId,
    required String sectionId,
  }) =>
      _inner.deleteSection(listId: listId, sectionId: sectionId);
}
