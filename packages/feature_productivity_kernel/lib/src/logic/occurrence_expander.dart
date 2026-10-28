import 'package:rrule/rrule.dart';

import '../models/calendar_event.dart';
import '../models/calendar_occurrence.dart';

/// 日历色兜底：colorByCalendar 缺失对应日历时用 Apple 蓝（契约 §8.1 平台 seed 色），
/// 避免竞态删除日历时 occurrence 变全透明。
const int kFallbackCalendarColorArgb = 0xFF007AFF;

/// 把主记录与例外行展开为时间窗 `[from, to)` 内的 occurrence（契约 §5.2 纯函数）。
///
/// - 重复主记录用 `package:rrule` 迭代（`rrule` 存储无 `RRULE:` 前缀，解析时补上）；
/// - 剔除 `exdates`（TC-CAL-KR-208）；
/// - 例外行（`parentEventId` 非空）替换主记录对应次（TC-CAL-KR-209）：
///   原始次不再输出，例外行若自身与窗口相交则独立呈现（支持被移进/移出窗口）；
/// - 单次事件与窗口相交即输出（左端排他、右端排他）；
/// - WKST：rrule 包仅支持周一，周起始只影响月网格与 BYWEEKNO，首期不支持
///   BYWEEKNO（契约 §5.2），此处不处理。
///
/// 与服务端 ical4j 展开共用 `recurrence_cases.json` 夹具做一致性验证
/// （TC-CAL-KR-201～209）。结果按 start 升序、同 start 按 end/eventId 稳定排序。
List<CalendarOccurrence> expandOccurrences(
  List<CalendarEvent> masters, {
  required DateTime from,
  required DateTime to,
  required Map<String, int> colorByCalendar,
}) {
  assert(!from.isAfter(to), '窗口 from 不得晚于 to');
  final result = <CalendarOccurrence>[];

  // 例外行按 (masterId, originalStart) 索引：主记录展开时跳过被替换的次。
  final exceptionOriginalKeys = <String>{};
  final exceptionRows = <CalendarEvent>[];
  for (final e in masters) {
    if (e.parentEventId == null) continue;
    exceptionRows.add(e);
    final original = e.originalStartAt;
    if (original != null) {
      exceptionOriginalKeys.add(_exceptionKey(e.parentEventId!, original));
    }
  }

  for (final master in masters) {
    if (master.parentEventId != null) continue; // 例外行走独立呈现逻辑
    final color = colorByCalendar[master.calendarId] ?? kFallbackCalendarColorArgb;

    if (master.rrule == null) {
      final occ = _singleOccurrence(master, from, to, color);
      if (occ != null) result.add(occ);
      continue;
    }

    // rrule 包要求 UTC DateTime 与 'RRULE:' 前缀（契约 §2.2 存储无前缀）。
    // 视图递给本函数的窗口是本地墙钟（anchorDateProvider 用 DateTime(y,m,d)），
    // 原样交给 getInstances 会撞 after/before 的 isUtc 断言，整个展开流抛异常，
    // 表现就是「设了重复的日程在日/月视图一并消失」（flutter #292）。
    // 这里只把三个入参换成同一瞬间的 UTC 值，瞬间比较语义不变。
    final rule = RecurrenceRule.fromString('RRULE:${master.rrule}');
    final duration = master.endAt.difference(master.startAt);
    final seed = master.startAt.toUtc();
    final windowFrom = from.toUtc();
    final windowTo = to.toUtc();
    // getInstances 的 before 断言要求 to >= 种子；种子已在窗外则无需展开。
    if (!seed.isBefore(windowTo)) continue;
    final instances = rule.getInstances(
      start: seed,
      after: windowFrom.isAfter(seed) ? windowFrom : null,
      includeAfter: true,
      before: windowTo,
    );
    for (final start in instances) {
      if (_containsInstant(master.exdates, start)) continue; // TC-CAL-KR-208
      final end = start.add(duration);
      if (!end.isAfter(from)) continue; // 与窗口无重叠
      if (exceptionOriginalKeys.contains(_exceptionKey(master.id, start))) {
        continue; // TC-CAL-KR-209：该次由例外行呈现
      }
      result.add(
        CalendarOccurrence(
          eventId: master.id,
          masterEventId: master.id,
          calendarId: master.calendarId,
          colorArgb: color,
          title: master.title,
          location: master.location,
          allDay: master.allDay,
          start: start,
          end: end,
          isRecurring: true,
          isException: false,
          status: master.status,
          source: OccurrenceSource.event,
        ),
      );
    }
  }

  // 例外行独立呈现：即便原始次不在窗内（被移进窗）也要显示。
  for (final ex in exceptionRows) {
    if (!ex.endAt.isAfter(from) || !ex.startAt.isBefore(to)) continue;
    result.add(
      CalendarOccurrence(
        eventId: ex.id,
        masterEventId: ex.parentEventId!,
        calendarId: ex.calendarId,
        colorArgb:
            colorByCalendar[ex.calendarId] ?? kFallbackCalendarColorArgb,
        title: ex.title,
        location: ex.location,
        allDay: ex.allDay,
        start: ex.startAt,
        end: ex.endAt,
        isRecurring: true,
        isException: true,
        status: ex.status,
        source: OccurrenceSource.event,
      ),
    );
  }

  result.sort(_byStart);
  return result;
}

CalendarOccurrence? _singleOccurrence(
  CalendarEvent event,
  DateTime from,
  DateTime to,
  int color,
) {
  if (!event.endAt.isAfter(from) || !event.startAt.isBefore(to)) return null;
  return CalendarOccurrence(
    eventId: event.id,
    masterEventId: event.id,
    calendarId: event.calendarId,
    colorArgb: color,
    title: event.title,
    location: event.location,
    allDay: event.allDay,
    start: event.startAt,
    end: event.endAt,
    isRecurring: false,
    isException: false,
    status: event.status,
    source: OccurrenceSource.event,
  );
}

/// exdates 存原始 occurrence 开始 UTC；按微秒时间戳精确匹配。
bool _containsInstant(List<DateTime> instants, DateTime candidate) {
  final epoch = candidate.microsecondsSinceEpoch;
  for (final t in instants) {
    if (t.microsecondsSinceEpoch == epoch) return true;
  }
  return false;
}

String _exceptionKey(String masterId, DateTime originalStart) =>
    '$masterId|${originalStart.microsecondsSinceEpoch}';

/// 稳定排序：start asc → end asc → eventId asc。
int _byStart(CalendarOccurrence a, CalendarOccurrence b) {
  final byStart = a.start.compareTo(b.start);
  if (byStart != 0) return byStart;
  final byEnd = a.end.compareTo(b.end);
  if (byEnd != 0) return byEnd;
  return a.eventId.compareTo(b.eventId);
}
