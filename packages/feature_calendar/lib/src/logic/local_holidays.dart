/// 本地节假日（lunar HolidayUtil）与本地订阅占位（F-16）。
///
/// 开源包不发 HTTP：订阅只保存 sourceUrl，真正拉取在 feature_calendar_cloud（F-17）。
library;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:lunar/lunar.dart';

import 'event_time.dart';

const String kHolidayCalendarId = 'calendar.holiday.cn';
const String kHolidayCalendarTitle = '中国大陆节假日';
const int kHolidayColorArgb = 0xFFFF3B30;

/// 一条中国法定节假日/调休。
class ChineseHoliday {
  const ChineseHoliday({
    required this.date,
    required this.name,
    required this.isOffDay,
  });

  final DateTime date;
  final String name;
  final bool isOffDay;
}

/// 某年的法定节假日（含调休上班日）。
List<ChineseHoliday> chineseHolidays(int year) {
  return [
    for (final h in HolidayUtil.getHolidaysByYear(year))
      ChineseHoliday(
        date: _parseDay(h.getDay()),
        name: h.getName(),
        isOffDay: !h.isWork(),
      ),
  ];
}

DateTime _parseDay(String day) {
  final parts = day.split('-');
  return DateTime(
      int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// 节假日 → 全天日程（只读日历；调休上班标题前缀「班」）。
List<CalendarEvent> holidayCalendarEvents(int year,
    {String timeZone = 'UTC'}) {
  final now = DateTime.now().toUtc();
  return [
    for (final h in chineseHolidays(year))
      CalendarEvent(
        id: '$kHolidayCalendarId:${_ymd(h.date)}',
        calendarId: kHolidayCalendarId,
        uid: 'holiday-${_ymd(h.date)}',
        title: h.isOffDay ? h.name : '班 ${h.name}',
        startAt: utcFromWall(h.date, timeZone),
        endAt: utcFromWall(DateTime(h.date.year, h.date.month, h.date.day + 1),
            timeZone),
        allDay: true,
        timeZone: timeZone,
        updatedAt: now,
      ),
  ];
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 确保本地节假日日历存在并写入该年数据（TC-CAL-UI-162）。
Future<Calendar> ensureLocalHolidayCalendar(
  CalendarRepository repository, {
  required int year,
  String timeZone = 'UTC',
  bool visible = true,
}) async {
  final calendars = await repository.watchCalendars().first;
  var calendar = calendars.where((c) => c.id == kHolidayCalendarId).firstOrNull;
  if (calendar == null) {
    calendar = const Calendar(
      id: kHolidayCalendarId,
      title: kHolidayCalendarTitle,
      colorArgb: kHolidayColorArgb,
      kind: CalendarKind.holiday,
      isVisible: true,
      isDefault: false,
    );
    await repository.upsertCalendar(calendar);
  }
  for (final event in holidayCalendarEvents(year, timeZone: timeZone)) {
    await repository.upsertEvent(event);
  }
  if (calendar.isVisible != visible) {
    await repository.setVisibility(id: kHolidayCalendarId, visible: visible);
  }
  return calendar;
}

/// 本地订阅占位：只落 sourceUrl，不发 HTTP（TC-CAL-UI-160）。
Future<Calendar> saveLocalSubscription(
  CalendarRepository repository, {
  required String url,
  required String title,
  int colorArgb = 0xFF007AFF,
}) async {
  final calendar = Calendar(
    id: 'calendar.subscription.${DateTime.now().microsecondsSinceEpoch}',
    title: title,
    colorArgb: colorArgb,
    kind: CalendarKind.subscription,
    sourceUrl: url,
    isVisible: true,
    isDefault: false,
  );
  await repository.upsertCalendar(calendar);
  return calendar;
}
