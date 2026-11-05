/// 提醒事项 → 日历 occurrence 投影（契约 §5.2 `projectScheduledReminders`；F-15）。
///
/// 只依赖 kernel 的提醒模型，不 import feature_task。
library;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// 定时提醒在日历里的展示时长（Apple 以点状条目呈现）。
const Duration kReminderProjectionDuration = Duration(minutes: 30);

/// 把带 `dueAt` 的提醒投影成 `source=reminder` 的 occurrence。
///
/// - `dueAt=null` 不投影（KR-403）
/// - 当地 00:00 视为全天（KR-402）
/// - 已完成仍投影但带 `completed=true`（KR-404）
/// - 重复提醒已完成时跳过（仓库完成即滚动到下一次；KR-405）
List<CalendarOccurrence> projectScheduledReminders(
  List<ReminderItem> items,
  List<ReminderList> lists, {
  required DateTime from,
  required DateTime to,
}) {
  final colorByList = {for (final l in lists) l.id: l.colorArgb};
  final result = <CalendarOccurrence>[];
  for (final item in items) {
    final due = item.dueAt;
    if (due == null || item.deletedAt != null) {
      continue;
    }
    if (item.recurrence != null && item.isCompleted) {
      continue; // 只显示下一次未完成
    }
    final allDay = due.hour == 0 && due.minute == 0 && due.second == 0;
    final start = due.toUtc();
    if (start.isBefore(from.toUtc()) || !start.isBefore(to.toUtc())) {
      continue;
    }
    final end = allDay
        ? start.add(const Duration(days: 1))
        : start.add(kReminderProjectionDuration);
    result.add(CalendarOccurrence(
      eventId: item.id,
      masterEventId: item.id,
      calendarId: 'reminder:${item.listId}',
      colorArgb: colorByList[item.listId] ?? 0xFF007AFF,
      title: item.title,
      allDay: allDay,
      start: start,
      end: end,
      isRecurring: item.recurrence != null,
      isException: false,
      source: OccurrenceSource.reminder,
      reminderId: item.id,
      completed: item.isCompleted,
    ));
  }
  result.sort((a, b) => a.start.compareTo(b.start));
  return result;
}
