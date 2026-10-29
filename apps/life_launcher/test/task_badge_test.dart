// TC-UI-4xx / #447：任务徽标数字（生产此前恒为 {}）。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/shell/task_badge.dart';

ReminderItem _item(
  String id, {
  DateTime? dueAt,
  bool completed = false,
  DateTime? deletedAt,
  String? parentId,
}) =>
    ReminderItem(
      id: id,
      listId: 'l1',
      title: id,
      dueAt: dueAt,
      isCompleted: completed,
      deletedAt: deletedAt,
      parentId: parentId,
    );

void main() {
  final now = DateTime(2026, 10, 29, 15, 30);

  test('#447 只数「今天到期且未完成」', () {
    final count = taskBadgeCount([
      _item('a', dueAt: DateTime(2026, 10, 29, 9)),
      _item('b', dueAt: DateTime(2026, 10, 29, 23, 59)),
      _item('c', dueAt: DateTime(2026, 10, 30, 9)), // 明天
      _item('d', dueAt: DateTime(2026, 10, 28, 9)), // 昨天（过期不算徽标）
      _item('e', dueAt: DateTime(2026, 10, 29, 9), completed: true), // 已完成
      _item('f'), // 无日期
    ], now: now);

    expect(count, 2);
  });

  test('#447 子任务与已删除不计数', () {
    final count = taskBadgeCount([
      _item('parent', dueAt: DateTime(2026, 10, 29, 9)),
      _item('child', dueAt: DateTime(2026, 10, 29, 9), parentId: 'parent'),
      _item('deleted', dueAt: DateTime(2026, 10, 29, 9), deletedAt: now),
    ], now: now);

    expect(count, 1, reason: '与侧栏口径一致：子任务不单独计数，删除的不算');
  });

  test('#447 同 id 不重复计数（去重）', () {
    final count = taskBadgeCount([
      _item('dup', dueAt: DateTime(2026, 10, 29, 9)),
      _item('dup', dueAt: DateTime(2026, 10, 29, 9)),
    ], now: now);
    expect(count, 1);
  });

  test('#447 includeTodayDue=false 时不数今天（为母卡 #419 的设置留位）', () {
    final count = taskBadgeCount([
      _item('a', dueAt: DateTime(2026, 10, 29, 9)),
    ], now: now, includeTodayDue: false);
    expect(count, 0);
  });

  test('#447 空列表 → 0（壳据此不显示徽标）', () {
    expect(taskBadgeCount(const [], now: now), 0);
  });
}
