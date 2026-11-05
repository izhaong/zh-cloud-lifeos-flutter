/// 日程提醒触发时刻（契约 §2.3；F-11）。
library;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'event_time.dart';

/// 定时事件允许的偏移（分钟；0=当时，负=提前）。
const List<int> kTimedAlertOffsets = [
  0,
  -5,
  -10,
  -15,
  -30,
  -60,
  -120,
  -1440,
  -2880,
  -10080,
];

/// 全天事件允许的「提前天数」（0=当天）。
const List<int> kAllDayAlertDays = [0, 1, 2, 7];

/// 定时提醒标签（Apple 预设译法）。
String timedAlertLabel(int offsetMinutes) {
  switch (offsetMinutes) {
    case 0:
      return '日程开始时';
    case -1440:
      return '1 天前';
    case -2880:
      return '2 天前';
    case -10080:
      return '1 周前';
    default:
      final n = -offsetMinutes;
      if (n % 60 == 0) {
        return '${n ~/ 60} 小时前';
      }
      return '$n 分钟前';
  }
}

/// 全天提醒标签。
String allDayAlertLabel(int days, String time) {
  switch (days) {
    case 0:
      return '当天 $time';
    case 1:
      return '前一天 $time';
    case 2:
      return '前两天 $time';
    case 7:
      return '前一周 $time';
    default:
      return '$days 天前 $time';
  }
}

/// 提醒 → 人类可读标签（表单 trailing / 对话框）。
String alertLabel(EventAlert alert, {required bool allDay}) {
  if (allDay) {
    final days = alert.allDayOffsetDays;
    if (days == null) {
      return '无';
    }
    return allDayAlertLabel(days, alert.allDayTime ?? '09:00');
  }
  final m = alert.offsetMinutes;
  return m == null ? '无' : timedAlertLabel(m);
}

/// 事件的全部提醒触发时刻（UTC，升序）。
///
/// [after] 非空时过滤已过期的触发（保存时只调度未来提醒）。
List<DateTime> calendarAlertTriggers(CalendarEvent event, {DateTime? after}) {
  final triggers = <DateTime>[];
  for (final alert in event.alerts) {
    if (event.allDay) {
      final days = alert.allDayOffsetDays;
      if (days == null) {
        continue;
      }
      final time = alert.allDayTime ?? '09:00';
      final parts = time.split(':');
      final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9;
      final minute =
          int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
      final wall = wallTimeOf(event.startAt, event.timeZone);
      // 日历日回退（DateTime 会规范化跨月/跨年）
      final day = DateTime(wall.year, wall.month, wall.day - days);
      triggers.add(utcFromWall(
          DateTime(day.year, day.month, day.day, hour, minute), event.timeZone));
    } else {
      final m = alert.offsetMinutes;
      if (m == null) {
        continue;
      }
      triggers.add(event.startAt.toUtc().add(Duration(minutes: m)));
    }
  }
  triggers.sort();
  if (after != null) {
    triggers.removeWhere((t) => !t.isAfter(after));
  }
  return triggers;
}
