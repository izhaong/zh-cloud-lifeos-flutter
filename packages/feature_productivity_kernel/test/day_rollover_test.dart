import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// 回归：跨午夜后智能列表（今天/计划）必须刷新。
///
/// 真实 bug：stream 只在写操作时 emit——app 跨午夜保持打开时，
/// 「今天」视图里仍躺着昨日条目（且分区头已标「已过期」，自相矛盾）。
void main() {
  test('跨日检查：本地日变化后重新广播计数与条目', () async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    repo.disposeDayRolloverWatch(); // 测试用手动检查，不要 60s 定时器
    await repo.upsertList(
        const ReminderList(id: 'list.p', title: '个人', colorArgb: 0xFF34C759));

    final day1 = DateTime(2026, 10, 25, 22, 0);
    repo.nowForTest = day1;
    await repo.upsertItem(ReminderItem(
        id: 'i1', listId: 'list.p', title: '昨天到期', dueAt: day1));
    await repo.upsertItem(ReminderItem(
        id: 'i2',
        listId: 'list.p',
        title: '次日项',
        dueAt: DateTime(2026, 10, 26, 9, 0)));

    // 首次检查：初始化「上次见到的日」（同日 → 不刷新）
    expect(repo.checkDayRollover(), isTrue, reason: '首次调用建立基线（last=null）');

    final before =
        await repo.watchItems(listId: 'smart.today').first;
    expect(before.map((e) => e.id), ['i1'], reason: '10/25 当天，i1 在「今天」');

    // 跨到次日：同一 repo 实例、无任何写操作
    repo.nowForTest = DateTime(2026, 10, 26, 0, 5);
    expect(repo.checkDayRollover(), isTrue, reason: '日界变化触发刷新');

    final after = await repo.watchItems(listId: 'smart.today').first;
    expect(after.map((e) => e.id), ['i1', 'i2'],
        reason: '跨日后 i1 转过期仍在「今天」，i2 进入「今天」');

    final scheduled =
        await repo.watchItems(listId: 'smart.scheduled').first;
    expect(scheduled.map((e) => e.id), ['i1', 'i2'],
        reason: '「计划」= dueAt 非空（含过期）');

    // 同日再检查：不得重复刷新
    expect(repo.checkDayRollover(), isFalse);
  });

  test('跨日刷新后侧栏「今天」保留过期项计数', () async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    repo.disposeDayRolloverWatch();
    await repo.upsertList(
        const ReminderList(id: 'list.p', title: '个人', colorArgb: 0xFF34C759));

    repo.nowForTest = DateTime(2026, 10, 25, 9, 0);
    await repo.upsertItem(ReminderItem(
        id: 'i1',
        listId: 'list.p',
        title: '当天项',
        dueAt: DateTime(2026, 10, 25, 9, 0)));
    repo.checkDayRollover();
    await repo.watchItems().first; // 触发 recount 后取一次

    var lists = await repo.watchLists().first;
    expect(lists.singleWhere((l) => l.id == 'smart.today').itemCount, 1);

    repo.nowForTest = DateTime(2026, 10, 26, 0, 1);
    expect(repo.checkDayRollover(), isTrue);

    lists = await repo.watchLists().first;
    expect(lists.singleWhere((l) => l.id == 'smart.today').itemCount, 1,
        reason: '跨日后 i1 转过期，仍计入「今天」');
  });
}
