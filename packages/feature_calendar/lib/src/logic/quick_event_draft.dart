/// 快速输入 → 日历草稿（#219）。
///
/// 未写日期的全天事件以「设备本地当天」为准：解析器按 now 的墙上日期定日期，
/// 但宿主时区与 UTC 有偏移时，直接沿用解析出的 UTC 时刻会在负偏移宿主上
/// 漂到前一天。这里用设备本地日重锚，是否写了日期由 [QuickEvent.dateExplicit] 区分。
library;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../nlp/quick_event_parser.dart';
import 'calendar_ids.dart';
import 'event_time.dart';

CalendarEvent quickEventDraft(
  QuickEvent quick, {
  required String timeZone,
  DateTime? now,
}) {
  final base = CalendarEvent(
    id: kDraftEventId,
    calendarId: '',
    uid: '',
    title: quick.title,
    startAt: quick.startAt,
    endAt: quick.endAt,
    allDay: quick.allDay,
    timeZone: timeZone,
    updatedAt: DateTime.now().toUtc(),
  );
  if (!quick.allDay || quick.dateExplicit) {
    return base;
  }
  final local = now ?? DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  return copyEventWithTimes(
    base,
    startAt: utcFromWall(day, timeZone),
    endAt: utcFromWall(DateTime(day.year, day.month, day.day + 1), timeZone),
  );
}
