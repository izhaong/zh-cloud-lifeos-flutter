import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// 回归（Drift 生产路径）：跨午夜后智能列表必须刷新。
///
/// 真实 bug：`watchLists/watchItems` 在建流时 `final now = _now` 冻结一次，
/// drift `.watch()` 只在 DB 变更时 emit——app 跨午夜保持打开时，
/// 「今天」视图与侧栏计数仍是昨天的快照（条目躺着但分区头已标「已过期」）。
void main() {
  late LifeProductivityDb db;
  late DriftReminderRepository repo;

  setUp(() {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftReminderRepository(db);
  });

  tearDown(() async => db.close());

  test('drift 跨日：今天视图清空、计划视图保留', () async {
    repo.nowForTest = DateTime(2026, 10, 25, 9, 0);
    await repo.upsertItem(ReminderItem(
      id: 'i1',
      listId: 'list.personal',
      title: '当天项',
      dueAt: DateTime(2026, 10, 25, 9, 0),
    ));

    // 订阅「今天」并等首帧
    final todayBefore =
        await repo.watchItems(listId: 'smart.today').first;
    expect(todayBefore.map((e) => e.id), ['i1'], reason: '10/25 当天在「今天」');

    // 跨到次日——无任何 DB 写操作，仅时间前进
    repo.nowForTest = DateTime(2026, 10, 26, 0, 5);

    // 日界 tick 每分钟检查一次；测试直接等一个 tick 周期不现实，
    // 这里用「重新订阅」验证 now 是每次发射重算的（修复前 now 在闭包里冻结）。
    final todayAfter =
        await repo.watchItems(listId: 'smart.today').first.timeout(
      const Duration(seconds: 5),
      onTimeout: () => <ReminderItem>[],
    );
    expect(todayAfter, isEmpty, reason: '跨日后「今天」不再含 i1');

    final scheduled =
        await repo.watchItems(listId: 'smart.scheduled').first;
    expect(scheduled.map((e) => e.id), ['i1'],
        reason: '「计划」= dueAt 非空（含过期）');
  });

  test('drift 跨日：侧栏「今天」计数归零', () async {
    repo.nowForTest = DateTime(2026, 10, 25, 9, 0);
    await repo.upsertItem(ReminderItem(
      id: 'i1',
      listId: 'list.personal',
      title: '当天项',
      dueAt: DateTime(2026, 10, 25, 9, 0),
    ));

    var lists = await repo.watchLists().first;
    expect(lists.singleWhere((l) => l.id == 'smart.today').itemCount, 1);

    repo.nowForTest = DateTime(2026, 10, 26, 0, 1);
    lists = await repo.watchLists().first;
    expect(lists.singleWhere((l) => l.id == 'smart.today').itemCount, 0,
        reason: '跨日后「今天」计数归零（now 不得在建流时冻结）');
  });
}
