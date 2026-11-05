/// 偏好全字段拷贝（kernel 无 copyWith；F-14）。
library;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

CalendarPreference copyCalendarPreference(
  CalendarPreference p, {
  String? defaultCalendarId,
  bool clearDefaultCalendar = false,
  int? startWeekOn,
  int? weekViewDays,
  int? dayStartHour,
  int? dayEndHour,
  int? hoursShown,
  bool? showDeclinedEvents,
  bool? timeZoneSupport,
  String? displayTimeZone,
  bool clearDisplayTimeZone = false,
  int? defaultAlertTimedMinutes,
  bool clearDefaultAlertTimed = false,
  int? defaultAlertAllDayDays,
  bool clearDefaultAlertAllDayDays = false,
  String? defaultAlertAllDayTime,
  int? defaultDurationMinutes,
  AlternateCalendar? alternateCalendar,
  bool? showWeekNumbers,
  bool? weekViewStartsToday,
  bool? showHolidays,
  bool? openEventsInWindow,
  int? revision,
}) {
  return CalendarPreference(
    defaultCalendarId: clearDefaultCalendar
        ? null
        : (defaultCalendarId ?? p.defaultCalendarId),
    startWeekOn: startWeekOn ?? p.startWeekOn,
    weekViewDays: weekViewDays ?? p.weekViewDays,
    dayStartHour: dayStartHour ?? p.dayStartHour,
    dayEndHour: dayEndHour ?? p.dayEndHour,
    hoursShown: hoursShown ?? p.hoursShown,
    showDeclinedEvents: showDeclinedEvents ?? p.showDeclinedEvents,
    timeZoneSupport: timeZoneSupport ?? p.timeZoneSupport,
    displayTimeZone: clearDisplayTimeZone
        ? null
        : (displayTimeZone ?? p.displayTimeZone),
    defaultAlertTimedMinutes: clearDefaultAlertTimed
        ? null
        : (defaultAlertTimedMinutes ?? p.defaultAlertTimedMinutes),
    defaultAlertAllDayDays: clearDefaultAlertAllDayDays
        ? null
        : (defaultAlertAllDayDays ?? p.defaultAlertAllDayDays),
    defaultAlertAllDayTime:
        defaultAlertAllDayTime ?? p.defaultAlertAllDayTime,
    defaultDurationMinutes:
        defaultDurationMinutes ?? p.defaultDurationMinutes,
    alternateCalendar: alternateCalendar ?? p.alternateCalendar,
    showWeekNumbers: showWeekNumbers ?? p.showWeekNumbers,
    weekViewStartsToday: weekViewStartsToday ?? p.weekViewStartsToday,
    showHolidays: showHolidays ?? p.showHolidays,
    openEventsInWindow: openEventsInWindow ?? p.openEventsInWindow,
    revision: revision ?? p.revision,
  );
}
