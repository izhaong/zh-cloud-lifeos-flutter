import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_test/flutter_test.dart';

/// #260 / Apple：提醒到点弹通知。这里钉住「什么时候该弹」的纯规则。
void main() {
  ReminderItem item({DateTime? dueAt, bool completed = false, DateTime? deletedAt}) =>
      ReminderItem(
        id: 'r1',
        listId: 'list.a',
        title: '买牛奶',
        dueAt: dueAt,
        isCompleted: completed,
        deletedAt: deletedAt,
      );

  test('带时分的到期时刻 → 就按那个时刻', () {
    final due = DateTime(2026, 10, 28, 18, 30);
    expect(reminderFireAt(item(dueAt: due), allDayNotify: true), due);
  });

  test('只有日期（00:00）→ 当天 09:00，且受「全天提醒时点」开关控制', () {
    final due = DateTime(2026, 10, 28);
    expect(
      reminderFireAt(item(dueAt: due), allDayNotify: true),
      DateTime(2026, 10, 28, 9),
    );
    expect(
      reminderFireAt(item(dueAt: due), allDayNotify: false),
      isNull,
      reason: '关掉全天提醒时点就不排',
    );
  });

  test('已完成 / 已删除 / 没有到期时间 → 不排', () {
    expect(reminderFireAt(item(dueAt: DateTime(2026, 10, 28, 18)), allDayNotify: true),
        isNotNull);
    expect(
      reminderFireAt(
        item(dueAt: DateTime(2026, 10, 28, 18), completed: true),
        allDayNotify: true,
      ),
      isNull,
    );
    expect(
      reminderFireAt(
        item(dueAt: DateTime(2026, 10, 28, 18), deletedAt: DateTime(2026, 10, 27)),
        allDayNotify: true,
      ),
      isNull,
    );
    expect(reminderFireAt(item(), allDayNotify: true), isNull);
  });
}
