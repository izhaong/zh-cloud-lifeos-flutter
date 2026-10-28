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
  // #230：节假日是应用内部生成的数据，必须走系统写入能力——节假日日历对
  // 用户编辑只读，用 upsertEvent 会抛 StateError 并让启动卡在 runApp 之前。
  // 实现层未提供该能力时（测试替身）退回 upsertEvent，保持既有替身可用。
  final systemWriter = repository is CalendarSystemWriter
      ? repository as CalendarSystemWriter
      : null;
  for (final event in holidayCalendarEvents(year, timeZone: timeZone)) {
    if (systemWriter != null) {
      await systemWriter.upsertSystemEvent(event);
    } else {
      await repository.upsertEvent(event);
    }
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

/// 已订阅节假日时按设备时区补齐当年数据（#182：UTC 墙钟会把节日挪到前一天，
/// 且跨年不补会整年缺失）。未订阅则什么都不做。
Future<void> refreshSubscribedHolidays(
  CalendarRepository repository, {
  int? year,
  String? timeZone,
}) async {
  final calendars = await repository.watchCalendars().first;
  final existing =
      calendars.where((c) => c.id == kHolidayCalendarId).firstOrNull;
  if (existing == null) {
    return;
  }
  await ensureLocalHolidayCalendar(
    repository,
    year: year ?? DateTime.now().year,
    timeZone: timeZone ?? await deviceTimeZoneName(),
    visible: existing.isVisible,
  );
}
