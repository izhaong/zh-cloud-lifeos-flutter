import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gitea flutter #292：给全天日程设「每周」并保存后，整页刷新（重开）该日程从日/月视图全部消失。
///
/// 真因不在持久化：`watchEvents` 能把带 `rrule` 的主记录正常取回；坏在
/// [expandOccurrences] 把视图给的**本地形状**窗口（`anchorDateNotifier` 造的是
/// `DateTime(y,m,d)`，`isUtc == false`）原样递给 `rrule` 的 `getInstances`，
/// 撞上该包对 `after`/`before` 的 `isUtc` 断言 → 整条展开流抛异常。
/// 不带 `rrule` 的日程走单次分支不受影响，所以现象正好是「只有设了重复的会消失」。
///
/// 本文件不锁机器时区：断言的是「同一瞬间的两种窗口形状必须展开出同一批
/// occurrence」——旧实现在本地形状那侧直接抛，故此测必然红在可归因处。
void main() {
  /// 上海 2026-10-28（周三）的一条全天日程；`repeat` 为空即未设重复。
  CalendarEvent allDayMaster({RecurrencePreset? repeat}) {
    final draft = CalendarEvent(
      id: 'e292',
      calendarId: 'c1',
      uid: 'u292',
      title: '基线',
      startAt: DateTime.utc(2026, 10, 27, 16), // 上海 10-28 00:00
      endAt: DateTime.utc(2026, 10, 28, 16), // 上海 10-29 00:00
      allDay: true,
      timeZone: 'Asia/Shanghai',
      updatedAt: DateTime.utc(2026, 10, 28),
    );
    // 与 inspector 保存前一致：先按全天归一，再用归一后的起点推重复周几。
    final normalized = normalizeAllDay(draft);
    final rrule = repeat == null
        ? null
        : rruleForPreset(repeat, normalized.startAt);
    return CalendarEvent(
      id: normalized.id,
      calendarId: normalized.calendarId,
      uid: normalized.uid,
      title: normalized.title,
      startAt: normalized.startAt,
      endAt: normalized.endAt,
      allDay: true,
      timeZone: normalized.timeZone,
      rrule: rrule,
      updatedAt: normalized.updatedAt,
    );
  }

  List<DateTime> starts(CalendarEvent master, DateTime from, DateTime to) =>
      expandOccurrences(
        [master],
        from: from,
        to: to,
        colorByCalendar: const {'c1': 0xFF007AFF},
      ).map((o) => o.start).toList();

  // 两周窗：起点即该日程当天 00:00（上海），终点 = 起点 + 14 天。
  final fromUtc = DateTime.utc(2026, 10, 27, 16);
  final toUtc = DateTime.utc(2026, 11, 10, 16);

  test('#292 本地形状窗口与 UTC 形状窗口必须展开出同一批 occurrence', () {
    final master = allDayMaster(repeat: RecurrencePreset.weekly);
    expect(rruleForPreset(RecurrencePreset.weekly, master.startAt),
        'FREQ=WEEKLY;BYDAY=TU',
        reason: '归一后的起点是 UTC 10-27T16:00（周二），规则按该起点推进');
    final utc = starts(master, fromUtc, toUtc);
    expect(utc, [DateTime.utc(2026, 10, 27, 16), DateTime.utc(2026, 11, 3, 16)],
        reason: '起点当天一次 + 一周后一次（上海每周三 00:00）');
    // 视图递过来的就是这个形状：同一瞬间，但 isUtc == false
    expect(starts(master, fromUtc.toLocal(), toUtc.toLocal()), utc,
        reason: '换个窗口形状不得改变展开结果（旧实现在此处抛 rrule 的 isUtc 断言）');
  });

  test('#292 设每周后，起点这一次仍在当天日窗内（Apple 期望）', () {
    final dayFrom = DateTime.utc(2026, 10, 27, 16);
    final dayTo = DateTime.utc(2026, 10, 28, 16);
    expect(
      starts(
        allDayMaster(repeat: RecurrencePreset.weekly),
        dayFrom.toLocal(),
        dayTo.toLocal(),
      ),
      [dayFrom],
      reason: '原日期这一次必须可见，不是移到下周、更不是整体消失',
    );
  });

  test('对照组：未设重复的同一天程一次可见，窗口推过终点即为空', () {
    final master = allDayMaster();
    expect(starts(master, fromUtc.toLocal(), toUtc.toLocal()), hasLength(1));
    expect(
      starts(master, toUtc, toUtc.add(const Duration(days: 1))),
      isEmpty,
      reason: '证明断言量的是窗口，不是常量',
    );
  });
}
