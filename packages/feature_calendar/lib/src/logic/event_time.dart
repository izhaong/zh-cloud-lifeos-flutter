import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 日期时间 / 全天 / 时区纯逻辑（契约 §2.2 归一规则；F-09）。
///
/// kernel 的 `startAt/endAt` 一律 UTC 时刻；`timeZone` 是 IANA 名。
/// 全天事件的规范形态：该时区当地 00:00 → 次日当地 00:00（排他）。

bool _tzReady = false;

void _ensureTimeZones() {
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
}

tz.Location _locationOf(String name) {
  _ensureTimeZones();
  try {
    return tz.getLocation(name);
  } catch (_) {
    return tz.UTC;
  }
}

/// UTC 时刻 → 指定时区的墙上时间（TZDateTime）。
DateTime wallTimeOf(DateTime instant, String timeZone) {
  return tz.TZDateTime.from(instant.toUtc(), _locationOf(timeZone));
}

/// 指定时区的墙上时间分量 → UTC 时刻。
DateTime utcFromWall(DateTime wall, String timeZone) {
  final loc = _locationOf(timeZone);
  return tz.TZDateTime(loc, wall.year, wall.month, wall.day, wall.hour,
          wall.minute, wall.second)
      .toUtc();
}

/// 时区名列表（timezone 包全量 + 合成的 UTC；排序稳定）。
List<String> allTimeZoneNames() {
  _ensureTimeZones();
  final names = tz.timeZoneDatabase.locations.keys.toSet();
  names.add('UTC'); // tz 数据常不含裸 UTC；草稿默认值要用
  return names.toList()..sort();
}

/// 设备本地时区（flutter_timezone）；测试/无插件环境回退 UTC。
Future<String> deviceTimeZoneName() async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    final id = info.identifier;
    _ensureTimeZones();
    return tz.timeZoneDatabase.locations.containsKey(id) ? id : 'UTC';
  } catch (_) {
    return 'UTC';
  }
}

/// 全天归一：按 `timeZone` 把开始归到当地 00:00、结束归到次日 00:00（转 UTC）。
CalendarEvent normalizeAllDay(CalendarEvent event, {String? timeZone}) {
  final zone = timeZone ?? event.timeZone;
  final wall = wallTimeOf(event.startAt, zone);
  final startLocal = DateTime(wall.year, wall.month, wall.day);
  // 日历日推进用「日+1」而非 add(24h)：后者在宿主时区 DST 日会变成 01:00。
  final endLocal = DateTime(wall.year, wall.month, wall.day + 1);
  return copyEventWithTimes(
    event,
    startAt: utcFromWall(startLocal, zone),
    endAt: utcFromWall(endLocal, zone),
    allDay: true,
    timeZone: zone,
  );
}

/// 取消全天：保持当天墙上日期，时间取当地 00:00 → 01:00。
CalendarEvent normalizeTimed(CalendarEvent event, {String? timeZone}) {
  final zone = timeZone ?? event.timeZone;
  final wall = wallTimeOf(event.startAt, zone);
  final startLocal = DateTime(wall.year, wall.month, wall.day, 0, 0);
  final endLocal = DateTime(wall.year, wall.month, wall.day, 1, 0);
  return copyEventWithTimes(
    event,
    startAt: utcFromWall(startLocal, zone),
    endAt: utcFromWall(endLocal, zone),
    allDay: false,
    timeZone: zone,
  );
}

/// 切换全天开关并按契约 §2.2 归一。
CalendarEvent setAllDay(CalendarEvent event, bool allDay, {String? timeZone}) {
  return allDay
      ? normalizeAllDay(event, timeZone: timeZone)
      : normalizeTimed(event, timeZone: timeZone);
}

/// 改开始时间：定时事件保持时长；全天事件按新日期重新归一。
CalendarEvent setStart(CalendarEvent event, DateTime newStartUtc, {String? timeZone}) {
  final zone = timeZone ?? event.timeZone;
  if (event.allDay) {
    return normalizeAllDay(
      copyEventWithTimes(event, startAt: newStartUtc, timeZone: zone),
      timeZone: zone,
    );
  }
  final duration = event.endAt.difference(event.startAt);
  return copyEventWithTimes(
    event,
    startAt: newStartUtc,
    endAt: newStartUtc.add(duration),
    timeZone: zone,
  );
}

/// 改结束时间（定时事件）。
CalendarEvent setEnd(CalendarEvent event, DateTime newEndUtc, {String? timeZone}) {
  final zone = timeZone ?? event.timeZone;
  if (event.allDay) {
    return normalizeAllDay(
      copyEventWithTimes(event, endAt: newEndUtc, timeZone: zone),
      timeZone: zone,
    );
  }
  return copyEventWithTimes(event, endAt: newEndUtc, timeZone: zone);
}

/// 换时区：保持墙上时间不变，换算 UTC 时刻（Apple「时区」语义）。
CalendarEvent setTimeZone(CalendarEvent event, String newTimeZone) {
  final oldZone = event.timeZone;
  final startWall = wallTimeOf(event.startAt, oldZone);
  final endWall = wallTimeOf(event.endAt, oldZone);
  final startLocal = DateTime(startWall.year, startWall.month, startWall.day,
      startWall.hour, startWall.minute);
  final endLocal = DateTime(endWall.year, endWall.month, endWall.day,
      endWall.hour, endWall.minute);
  final moved = copyEventWithTimes(
    event,
    startAt: utcFromWall(startLocal, newTimeZone),
    endAt: utcFromWall(endLocal, newTimeZone),
    timeZone: newTimeZone,
  );
  return event.allDay ? normalizeAllDay(moved, timeZone: newTimeZone) : moved;
}

/// 展示用墙上时间（全天只给日期）。
String formatEventWall(DateTime instantUtc, String timeZone, {bool allDay = false}) {
  final wall = wallTimeOf(instantUtc, timeZone);
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${wall.year}-${two(wall.month)}-${two(wall.day)}';
  if (allDay) {
    return date;
  }
  return '$date ${two(wall.hour)}:${two(wall.minute)}';
}

/// 全字段替换时间字段（kernel 无 copyWith）。
CalendarEvent copyEventWithTimes(
  CalendarEvent e, {
  DateTime? startAt,
  DateTime? endAt,
  bool? allDay,
  String? timeZone,
  bool? isFloating,
}) {
  return CalendarEvent(
    id: e.id,
    remoteId: e.remoteId,
    calendarId: e.calendarId,
    uid: e.uid,
    title: e.title,
    location: e.location,
    url: e.url,
    notes: e.notes,
    startAt: startAt ?? e.startAt,
    endAt: endAt ?? e.endAt,
    allDay: allDay ?? e.allDay,
    timeZone: timeZone ?? e.timeZone,
    isFloating: isFloating ?? e.isFloating,
    rrule: e.rrule,
    exdates: e.exdates,
    parentEventId: e.parentEventId,
    originalStartAt: e.originalStartAt,
    status: e.status,
    availability: e.availability,
    travelMinutes: e.travelMinutes,
    isPrivate: e.isPrivate,
    alerts: e.alerts,
    invitees: e.invitees,
    sequence: e.sequence,
    revision: e.revision,
    deletedAt: e.deletedAt,
    updatedAt: e.updatedAt,
  );
}
