import 'package:drift/native.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_launcher/main.dart' show runNonFatalStartupStep;

/// #230 回归：订阅过「中国大陆节假日」后，macOS/持久库端每次启动都纯黑。
///
/// 成因链：`main()` 在 `runApp` 前 `await refreshSubscribedHolidays(...)`，
/// 补齐节假日时用**用户写入路径** `upsertEvent` 写 `kind=HOLIDAY` 日历，
/// 被只读守卫判为非法 ⇒ 抛 `StateError` ⇒ `runApp` 永不执行。
///
/// 本用例用真实 Drift 仓库复现（与桌面端同一组合根），钉住两条口径：
/// 1. 用户写入路径仍然拒绝只读节假日日历（TC-CAL-KR-510 不放宽）；
/// 2. 启动补齐走系统写入能力能成功，`refreshSubscribedHolidays` 不抛。
void main() {
  late LifeProductivityDb db;
  late DriftCalendarRepository repo;

  setUp(() async {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = openDefaultDriftCalendarRepository(db);
  });

  tearDown(() async => db.close());

  CalendarEvent holidayEvent() => CalendarEvent(
        id: '$kHolidayCalendarId:2026-01-01',
        calendarId: kHolidayCalendarId,
        uid: 'holiday-2026-01-01',
        title: '元旦',
        startAt: DateTime.utc(2026, 1, 1),
        endAt: DateTime.utc(2026, 1, 2),
        allDay: true,
        timeZone: 'Asia/Shanghai',
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  /// 复刻「用户曾订阅过节假日」的持久库状态。
  Future<void> seedSubscribedHolidayCalendar() => repo.upsertCalendar(
        const Calendar(
          id: kHolidayCalendarId,
          title: kHolidayCalendarTitle,
          colorArgb: kHolidayColorArgb,
          kind: CalendarKind.holiday,
          isVisible: true,
          isDefault: false,
        ),
      );

  test('#230 用户写入路径仍拒绝只读节假日日历（TC-CAL-KR-510）', () async {
    await seedSubscribedHolidayCalendar();
    await expectLater(
      repo.upsertEvent(holidayEvent()),
      throwsStateError,
      reason: '订阅/节假日日历对用户编辑只读，规则不放宽',
    );
    final rows = await db.select(db.calendarEvents).get();
    expect(rows, isEmpty, reason: '库无新行');
  });

  test('#230 系统写入能力可补齐节假日（不成为绕过只读的后门）', () async {
    await seedSubscribedHolidayCalendar();
    final writer = repo as CalendarSystemWriter;

    await writer.upsertSystemEvent(holidayEvent());
    final rows = await db.select(db.calendarEvents).get();
    expect(rows.single.id, '$kHolidayCalendarId:2026-01-01',
        reason: '系统生成日程落库');

    // 只允许落到系统日历（holiday/subscription）；本地日历不给后门。
    await repo.upsertCalendar(const Calendar(
      id: 'cal-local',
      title: '个人',
      colorArgb: 0xFF007AFF,
    ));
    await expectLater(
      writer.upsertSystemEvent(CalendarEvent(
        id: 'sneaky',
        calendarId: 'cal-local',
        uid: 'sneaky',
        title: '偷写',
        startAt: DateTime.utc(2026, 1, 1),
        endAt: DateTime.utc(2026, 1, 2),
        allDay: true,
        timeZone: 'Asia/Shanghai',
        updatedAt: DateTime.utc(2026, 1, 1),
      )),
      throwsStateError,
      reason: '系统写入只能落在系统日历，不能绕过用户路径的写权限模型',
    );
  });

  test('#230 已订阅节假日 → 启动补齐不抛（原黑屏成因）', () async {
    await seedSubscribedHolidayCalendar();

    // 修复前：这条 await 抛 StateError，main() 永远走不到 runApp。
    await expectLater(
      refreshSubscribedHolidays(repo, year: 2026, timeZone: 'Asia/Shanghai'),
      completes,
    );

    final events = await repo
        .watchEvents(
          from: DateTime.utc(2026, 1, 1),
          to: DateTime.utc(2027, 1, 1),
        )
        .first;
    expect(events, isNotEmpty, reason: '节假日事件已补齐（重启后仍能看到）');
    expect(
      events.every((e) => e.calendarId == kHolidayCalendarId && e.allDay),
      isTrue,
    );
  });

  test('#230 未订阅节假日 → 启动补齐不建日历也不写事件', () async {
    await refreshSubscribedHolidays(repo, year: 2026, timeZone: 'Asia/Shanghai');
    final calendars = await repo.watchCalendars().first;
    final events = await db.select(db.calendarEvents).get();
    expect(calendars, isEmpty);
    expect(events, isEmpty);
  });

  // main() 的第二道兜底：即便某天又出现新的只读/数据异常，预热失败也只记日志。
  test('#230 runNonFatalStartupStep 吞掉预热异常、后续步骤照跑', () async {
    final ran = <String>[];
    await runNonFatalStartupStep('会抛的步骤', () async {
      ran.add('bad');
      throw StateError('该日历为只读：calendar.holiday.cn');
    });
    await runNonFatalStartupStep('正常步骤', () async => ran.add('good'));

    expect(ran, ['bad', 'good'], reason: '异常不得中断启动链路');
  });
}
