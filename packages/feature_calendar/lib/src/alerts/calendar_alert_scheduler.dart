/// 日程提醒调度端口（F-11）。
///
/// 开源 `feature_calendar` 只声明接口；真实本地通知在 `life_launcher` 注入。
/// 默认 [NoopCalendarAlertScheduler]：测试/无壳环境不弹通知。
library;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class CalendarAlertScheduler {
  /// 为事件的全部提醒排期（实现方负责先取消同事件的旧通知）。
  Future<void> scheduleEvent(CalendarEvent event);

  /// 取消该事件的所有通知。
  Future<void> cancelEvent(String eventId);

  /// 「稍后提醒」：在 [fireAt] 补一条通知。
  Future<void> snooze(CalendarEvent event, DateTime fireAt);
}

class NoopCalendarAlertScheduler implements CalendarAlertScheduler {
  const NoopCalendarAlertScheduler();

  @override
  Future<void> scheduleEvent(CalendarEvent event) async {}

  @override
  Future<void> cancelEvent(String eventId) async {}

  @override
  Future<void> snooze(CalendarEvent event, DateTime fireAt) async {}
}

final calendarAlertSchedulerProvider =
    Provider<CalendarAlertScheduler>((ref) => const NoopCalendarAlertScheduler());

/// 通知动作处理（关闭 / 稍后 9 分钟；F-11 TC-CAL-UI-154）。
class CalendarNotificationActions {
  CalendarNotificationActions(this.scheduler, {this.clock});

  final CalendarAlertScheduler scheduler;

  /// 可注入时钟（测试断言触发时刻）。
  final DateTime Function()? clock;

  static const Duration snoozeDelay = Duration(minutes: 9);

  Future<void> onSnooze(CalendarEvent event) {
    final now = (clock ?? () => DateTime.now().toUtc())();
    return scheduler.snooze(event, now.toUtc().add(snoozeDelay));
  }

  Future<void> onDismiss(String eventId) => scheduler.cancelEvent(eventId);
}
