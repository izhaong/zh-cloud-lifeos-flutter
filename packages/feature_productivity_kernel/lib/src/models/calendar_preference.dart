import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// 备选历法（契约 §2.9；HEBREW/ISLAMIC 后置，首期只有 CHINESE）。
enum AlternateCalendar {
  none,
  chinese;

  String get id => switch (this) {
        AlternateCalendar.none => 'NONE',
        AlternateCalendar.chinese => 'CHINESE',
      };

  static AlternateCalendar? fromId(String? id) {
    if (id == null) return null;
    for (final a in AlternateCalendar.values) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// 用户偏好（契约 §2.9，每用户一行；字段与列一一对应，驼峰）。
@immutable
final class CalendarPreference extends Equatable {
  const CalendarPreference({
    this.defaultCalendarId,
    this.startWeekOn = 1,
    this.weekViewDays = 7,
    this.dayStartHour = 8,
    this.dayEndHour = 18,
    this.hoursShown = 12,
    this.showDeclinedEvents = false,
    this.timeZoneSupport = false,
    this.displayTimeZone,
    this.defaultAlertTimedMinutes,
    this.defaultAlertAllDayDays,
    this.defaultAlertAllDayTime = '09:00',
    this.defaultDurationMinutes = 60,
    this.alternateCalendar = AlternateCalendar.none,
    this.showWeekNumbers = false,
    this.weekViewStartsToday = false,
    this.showHolidays = true,
    this.openEventsInWindow = false,
    this.revision = 1,
  });

  /// 新建日程默认日历（D-37；null = 未设置）。
  final String? defaultCalendarId;

  /// 周起始（`1`=周一 / `7`=周日，D-04/D-45）。
  final int startWeekOn;

  /// 周视图显示天数（5 或 7，D-01）。
  final int weekViewDays;

  /// 日视图起始小时（D-03）。
  final int dayStartHour;

  /// 日视图结束小时（D-03）。
  final int dayEndHour;

  /// 显示小时数（6–24，D-02）。
  final int hoursShown;

  /// 显示已拒绝邀请（C-137）。
  final bool showDeclinedEvents;

  /// 开启时区支持（D-16）。
  final bool timeZoneSupport;

  /// 显示时区（IANA；null = 跟随设备，D-34）。
  final String? displayTimeZone;

  /// 定时事件默认提醒分钟（D-38；null = 无）。
  final int? defaultAlertTimedMinutes;

  /// 全天事件默认提前天数（null = 无）。
  final int? defaultAlertAllDayDays;

  /// 全天事件默认提醒时刻 `HH:mm`。
  final String defaultAlertAllDayTime;

  /// 新日程默认时长分钟（D-40）。
  final int defaultDurationMinutes;

  /// 备选历法（D-07/D-42）。
  final AlternateCalendar alternateCalendar;

  /// 显示周数（D-17/D-43）。
  final bool showWeekNumbers;

  /// 周视图从今天开始（D-44）。
  final bool weekViewStartsToday;

  /// 显示节假日日历（D-06）。
  final bool showHolidays;

  /// 在独立窗口打开日程（Mac D-18）。
  final bool openEventsInWindow;

  /// 保存次数（每次保存 +1，服务端 §3.8 同口径）。
  final int revision;

  /// 契约 §2.9 默认值（服务端 GET /preference/get 未建行时同口径返回，不写库）。
  static const CalendarPreference defaults = CalendarPreference();

  @override
  List<Object?> get props => [
        defaultCalendarId,
        startWeekOn,
        weekViewDays,
        dayStartHour,
        dayEndHour,
        hoursShown,
        showDeclinedEvents,
        timeZoneSupport,
        displayTimeZone,
        defaultAlertTimedMinutes,
        defaultAlertAllDayDays,
        defaultAlertAllDayTime,
        defaultDurationMinutes,
        alternateCalendar,
        showWeekNumbers,
        weekViewStartsToday,
        showHolidays,
        openEventsInWindow,
        revision,
      ];
}
