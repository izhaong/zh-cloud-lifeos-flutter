import 'package:kalender/kalender.dart' as kalender;

/// #225：日/周视图「双击创建」节拍器。
///
/// kalender 0.33.0 没有双击识别器（库内 DoubleTap 零命中），但空区单点会经
/// `KalenderCallbacks.onTappedWithDetail` 上报：
/// - 定时区（日/周 body）→ [kalender.DayDetail]，`date` 已是像素换算并吸附后的精确时刻；
/// - 全天区（header 带）→ [kalender.MultiDayDetail]，`dateTimeRange` 为该日 00:00–24:00。
///
/// 两次点按 ≤[window] 且同一天、同区（定时/全天）即视为一次双击；
/// 单击不产生任何副作用（Apple：日/周空区单击无动作）。
class CalendarDoubleTapTracker {
  /// 判定为双击的最大点按间隔。
  static const window = Duration(milliseconds: 400);

  DateTime? _lastAt;
  DateTime? _lastDay;
  bool _lastAllDay = false;

  /// 记录一次空区点按；返回 true 表示与上一次构成双击（调用方随后创建草稿）。
  bool register({
    required DateTime day,
    bool allDay = false,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final isDouble = _lastAt != null &&
        _lastDay == day &&
        _lastAllDay == allDay &&
        t.difference(_lastAt!) <= window;
    // 重置节拍：避免三连击触发两次创建。
    _lastAt = isDouble ? null : t;
    _lastDay = isDouble ? null : day;
    _lastAllDay = allDay;
    return isDouble;
  }
}

/// #225：月视图「一次创建」闸门。
///
/// 月格空区的单击本来就经 `onTapped` 创建全天草稿（TC-CAL-UI-131 既有口径），
/// 因此双击的第一下已经会弹出草稿；**第二下必须吞掉**——否则它会落在刚打开的
/// 草稿弹层遮罩上把草稿关掉，用户看到的就是「双击什么也没发生」（#225 实测现象）。
class CalendarTapGate {
  /// 判定为「同一次双击的第二下」的最大间隔。
  static const window = Duration(milliseconds: 400);

  DateTime? _lastAt;
  DateTime? _lastDay;

  /// 返回 true 表示应当创建草稿；false 表示这是双击的第二下，吞掉。
  bool allow(DateTime day, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final isSecond =
        _lastAt != null && _lastDay == day && t.difference(_lastAt!) <= window;
    if (isSecond) {
      // 节拍清零：三连击视为新的一次双击，不会无限吞掉。
      _lastAt = null;
      _lastDay = null;
      return false;
    }
    _lastAt = t;
    _lastDay = day;
    return true;
  }
}

/// #225：把 kalender 空区点按翻译成「双击创建」语义。
///
/// - 定时区双击 → [onDraftCreate]（起点=双击时刻，时长由回调取偏好默认）；
/// - 全天区双击 → [onDayTap]（该日全天草稿，TC-CAL-UI-131 口径）。
/// 返回该次点按是否落在可创建区（false=未识别的 detail 类型）。
bool handleCalendarTapCreate(
  kalender.TapDetail detail,
  CalendarDoubleTapTracker tracker, {
  required void Function(DateTime start, DateTime end) onDraftCreate,
  required void Function(DateTime day) onDayTap,
}) {
  if (detail is kalender.DayDetail) {
    final date = detail.date;
    final day = DateTime(date.year, date.month, date.day);
    if (tracker.register(day: day)) {
      onDraftCreate(date, date);
    }
    return true;
  }
  if (detail is kalender.MultiDayDetail) {
    final start = detail.dateTimeRange.start;
    final day = DateTime(start.year, start.month, start.day);
    if (tracker.register(day: day, allDay: true)) {
      onDayTap(day);
    }
    return true;
  }
  return false;
}
