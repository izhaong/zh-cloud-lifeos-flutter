import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 任务提醒的**本地通知**端口（Apple：提醒到点弹通知）。
///
/// 开源包只声明接口；真实实现依赖 `flutter_local_notifications`，由壳层
/// `life_launcher` 注入（与日历的 `CalendarAlertScheduler` 同一套路）。
abstract interface class ReminderAlertScheduler {
  /// 按库中当前内容重排全部本地通知（幂等；新的/改期/完成/删除都靠它收敛）。
  Future<void> rescheduleAll();

  /// 清掉本调度器排过的全部通知。
  Future<void> cancelAll();
}

/// 默认空实现：未注入真实调度器（测试/未登录）时静默不排。
final class NoopReminderAlertScheduler implements ReminderAlertScheduler {
  const NoopReminderAlertScheduler();

  @override
  Future<void> rescheduleAll() async {}

  @override
  Future<void> cancelAll() async {}
}

/// 组合根注入点（life_launcher 用真实实现覆盖）。
final reminderAlertSchedulerProvider = Provider<ReminderAlertScheduler>(
  (ref) => const NoopReminderAlertScheduler(),
);

/// 一条提醒应该在什么时刻弹通知（纯函数，便于单测）。
///
/// - 带时分的 `dueAt`：就按那个时刻；
/// - **只有日期**（00:00 视为「全天/只订了哪一天」）：Apple 默认当天 09:00 提醒，
///   且受设置里的「全天提醒时点」开关控制，关掉则不排；
/// - 已过期的时刻不再补弹（避免重开应用时一次性炸出历史提醒）。
DateTime? reminderFireAt(
  ReminderItem item, {
  required bool allDayNotify,
}) {
  if (item.isCompleted || item.deletedAt != null) return null;
  final due = item.dueAt;
  if (due == null) return null;
  final isDateOnly = due.hour == 0 && due.minute == 0 && due.second == 0;
  if (!isDateOnly) return due;
  if (!allDayNotify) return null;
  return DateTime(due.year, due.month, due.day, 9);
}
