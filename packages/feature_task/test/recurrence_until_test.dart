import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TC-UI-319（T-04）：重复结束日期——
/// - 滚动时 nextOccurrence 晚于 recurrenceUntil 当天结束 → 真正完成、不再滚动
/// - 未越过结束日期 → 照常滚动（含当天：结束日当天仍出现）
/// - 详情重复区出现「结束日期」行（有规则才显示；空=永不）
void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('TC-UI-319 kernel 语义', () {
    testWidgets('越过结束日期：完成=真完成不滚动', (tester) async {
      final repo = InMemoryReminderRepository(seedSampleData: false);
      await repo.upsertList(
          const ReminderList(id: 'list.t', title: '测试', colorArgb: 0xFF007AFF));
      final today = DateTime.now();
      await repo.upsertItem(ReminderItem(
        id: 'r1',
        listId: 'list.t',
        title: '每天喝水',
        dueAt: today,
        recurrence: 'daily',
        recurrenceUntil: today, // 结束日=今天：今天完成后，明天不该再滚动
      ));

      await repo.toggleCompleted('r1');

      final after = await repo
          .watchItems()
          .first
          .then((all) => all.singleWhere((e) => e.id == 'r1'));
      expect(after.isCompleted, isTrue, reason: '越过结束日 → 真完成');
      expect(after.dueAt, today, reason: 'dueAt 不滚动');
    });

    testWidgets('未越结束日期：照常滚动（完成态回 false）', (tester) async {
      final repo = InMemoryReminderRepository(seedSampleData: false);
      await repo.upsertList(
          const ReminderList(id: 'list.t', title: '测试', colorArgb: 0xFF007AFF));
      final today = DateTime.now();
      final farEnd = today.add(const Duration(days: 30));
      await repo.upsertItem(ReminderItem(
        id: 'r2',
        listId: 'list.t',
        title: '每天读书',
        dueAt: today,
        recurrence: 'daily',
        recurrenceUntil: farEnd,
      ));

      await repo.toggleCompleted('r2');

      final after = await repo
          .watchItems()
          .first
          .then((all) => all.singleWhere((e) => e.id == 'r2'));
      expect(after.isCompleted, isFalse, reason: '未越结束日 → 滚动');
      expect(after.dueAt!.isAfter(today), isTrue, reason: 'dueAt 前滚');
    });

    testWidgets('无结束日期（null=永不）：照常滚动', (tester) async {
      final repo = InMemoryReminderRepository(seedSampleData: false);
      await repo.upsertList(
          const ReminderList(id: 'list.t', title: '测试', colorArgb: 0xFF007AFF));
      final today = DateTime.now();
      await repo.upsertItem(ReminderItem(
        id: 'r3',
        listId: 'list.t',
        title: '每天锻炼',
        dueAt: today,
        recurrence: 'daily',
      ));

      await repo.toggleCompleted('r3');

      final after = await repo
          .watchItems()
          .first
          .then((all) => all.singleWhere((e) => e.id == 'r3'));
      expect(after.isCompleted, isFalse);
      expect(after.dueAt!.isAfter(today), isTrue);
    });
  });

  testWidgets('TC-UI-319 详情重复区出现「结束日期」行（有规则才显示）', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
        const ReminderList(id: 'list.t', title: '测试', colorArgb: 0xFF007AFF));
    final today = DateTime.now();
    await repo.upsertItem(ReminderItem(
      id: 'r4',
      listId: 'list.t',
      title: '每天背单词',
      dueAt: today,
      recurrence: 'daily',
    ));

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: TaskScaffold(openListId: 'list.t'),
      ),
    ));
    await tester.pumpAndSettle();

    // 点行开 inspector → 重复区有「结束日期」行，值为「永不」
    await tester.tap(find.text('每天背单词'));
    await tester.pumpAndSettle();
    expect(find.text('结束日期'), findsOneWidget);
    expect(find.text('永不'), findsOneWidget);
  });
}
