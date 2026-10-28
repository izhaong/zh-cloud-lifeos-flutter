import 'dart:io';

import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drift 日历仓库契约测试（TC-CAL-KR-501～510；契约 §5.3，F-02）。
/// 全字段重建（kernel.CalendarEvent 暂无 copyWith；仅测试用）。
CalendarEvent _withTitle(CalendarEvent e, String title) {
  return CalendarEvent(
    id: e.id,
    remoteId: e.remoteId,
    calendarId: e.calendarId,
    uid: e.uid,
    title: title,
    location: e.location,
    url: e.url,
    notes: e.notes,
    startAt: e.startAt,
    endAt: e.endAt,
    allDay: e.allDay,
    timeZone: e.timeZone,
    isFloating: e.isFloating,
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

void main() {
  late LifeProductivityDb db;
  late DriftCalendarRepository repo;

  Calendar cal({
    String id = 'cal1',
    String title = '个人',
    int color = 0xFF007AFF,
    CalendarKind kind = CalendarKind.local,
    bool isDefault = false,
  }) {
    return Calendar(
      id: id,
      title: title,
      colorArgb: color,
      kind: kind,
      isDefault: isDefault,
    );
  }

  CalendarEvent event({
    String id = 'e1',
    String calendarId = 'cal1',
    String title = '周会',
    DateTime? startAt,
    DateTime? endAt,
    String? rrule,
    List<DateTime> exdates = const [],
    String? location,
  }) {
    final s = startAt ?? DateTime.utc(2026, 11, 2, 9);
    return CalendarEvent(
      id: id,
      calendarId: calendarId,
      uid: 'uid-$id',
      title: title,
      location: location,
      startAt: s,
      endAt: endAt ?? s.add(const Duration(hours: 1)),
      timeZone: 'Asia/Shanghai',
      updatedAt: DateTime.utc(2026, 10, 24),
      rrule: rrule,
      exdates: exdates,
    );
  }

  setUp(() {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftCalendarRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // TC-CAL-KR-501：v6 迁移到 v7 —— 旧 reminder 仍在，三张日历表存在。
  test('TC-CAL-KR-501 v6 迁移到 v7', () async {
    final dir = await Directory.systemTemp.createTemp('cal_drift_v7');
    final file = File('${dir.path}/legacy_v6.db');
    addTearDown(() => dir.deleteSync(recursive: true));

    // 1) 先用 v7 类建全量表 + 灌一条 reminder，再降回 v6 形态
    //    （v7 未改 reminder 两表，v6 形态 = 去掉三张日历表 + user_version=6）
    final seed = LifeProductivityDb(NativeDatabase(file));
    await seed.into(seed.reminderItems).insert(
          ReminderItemsCompanion.insert(
            id: 'r1',
            listId: 'list.personal',
            title: '买牛奶',
          ),
        );
    seed.customStatement('DROP TABLE IF EXISTS calendar_events');
    seed.customStatement('DROP TABLE IF EXISTS calendars');
    seed.customStatement('DROP TABLE IF EXISTS calendar_preferences');
    seed.customStatement('DROP INDEX IF EXISTS idx_calendar_events_cal_start');
    // T-04（V8）：建表类已含 recurrence_until；降到 v6 基线须一并移除，
    // 否则重开时 from=6 的 V8 加列与现存列冲突（duplicate column）
    seed.customStatement(
        'ALTER TABLE reminder_items DROP COLUMN recurrence_until');
        // V14（flutter#144）：reminder_lists 新增 remote_id；降到 v6 基线
    // 须一并移除，否则重开时 from<14 的加列与现存列冲突（duplicate column）
    seed.customStatement('ALTER TABLE reminder_lists DROP COLUMN remote_id');
    // V16（flutter#278）：reminder_items 新增 created_at；降到 v6 基线
    // 须一并移除，否则重开时 from<16 的加列与现存列冲突（duplicate column）
    seed.customStatement('ALTER TABLE reminder_items DROP COLUMN created_at');
    seed.customStatement('PRAGMA user_version = 6');
    await seed.close();

    // 2) 重新打开 → from=6 迁移到 7
    final reopened = LifeProductivityDb(NativeDatabase(file));
    addTearDown(reopened.close);
    final reminders = DriftReminderRepository(reopened).watchItems().first;
    expect((await reminders).map((e) => e.id), ['r1'], reason: '旧 reminder 仍在');
    final calendars = await DriftCalendarRepository(reopened).watchCalendars().first;
    expect(calendars, isEmpty, reason: '三张日历表已由迁移创建且可查询');
  });

  // TC-CAL-KR-502：日历往返 —— upsert 后 watch 字段相等（含 color/kind/isDefault）。
  test('TC-CAL-KR-502 日历往返', () async {
    final c = cal(id: 'cal.work', title: '工作', color: 0xFF34C759, isDefault: true);
    await repo.upsertCalendar(c);
    final seen = await repo.watchCalendars().first;
    expect(seen, [c]);
    final byId = seen.single;
    expect(byId.colorArgb, 0xFF34C759);
    expect(byId.kind, CalendarKind.local);
    expect(byId.isDefault, isTrue);
  });

  // TC-CAL-KR-503：事件往返 —— rrule/alerts/exdates 经 JSON 列读回后列表相等。
  test('TC-CAL-KR-503 事件往返', () async {
    await repo.upsertCalendar(cal());
    final e = CalendarEvent(
      id: 'e.rrule',
      calendarId: 'cal1',
      uid: 'uid-1',
      title: '每周例会',
      startAt: DateTime.utc(2026, 11, 2, 9),
      endAt: DateTime.utc(2026, 11, 2, 10),
      timeZone: 'Asia/Shanghai',
      rrule: 'FREQ=WEEKLY;BYDAY=MO,WE',
      exdates: [DateTime.utc(2026, 11, 4, 9)],
      alerts: const [EventAlert(offsetMinutes: -15), EventAlert(allDayOffsetDays: 0, allDayTime: '09:00')],
      invitees: const [EventInvitee(memberUserId: 'm1', displayName: '张三', role: InviteeRole.required, partstat: PartStat.accepted)],
      updatedAt: DateTime.utc(2026, 10, 24),
    );
    await repo.upsertEvent(e);
    final got = await repo.getEvent('e.rrule');
    expect(got, e, reason: '字段往返相等（含 rrule/alerts/exdates/invitees）');
    expect(got!.exdates, [DateTime.utc(2026, 11, 4, 9)]);
    expect(got.alerts.length, 2);
    expect(got.invitees.single.partstat, PartStat.accepted);
  });

  // TC-CAL-KR-504：软删 —— watch 窗口里消失，行仍在且 deletedAt 非空。
  test('TC-CAL-KR-504 软删', () async {
    await repo.upsertCalendar(cal());
    await repo.upsertEvent(event());
    await repo.deleteEvent('e1');

    final seen = await repo.watchEvents(
      from: DateTime.utc(2026, 11, 1),
      to: DateTime.utc(2026, 11, 8),
    ).first;
    expect(seen.map((e) => e.id), isNot(contains('e1')));

    final row = await (db.select(db.calendarEvents)
          ..where((t) => t.id.equals('e1')))
        .getSingleOrNull();
    expect(row, isNotNull, reason: '软删行仍在');
    expect(row!.deletedAt, isNotNull);
  });

  // TC-CAL-KR-505：偏好单行 —— 连续 save 两次仍一行，revision=2。
  test('TC-CAL-KR-505 偏好单行', () async {
    await repo.savePreference(
      const CalendarPreference(defaultDurationMinutes: 45),
    );
    await repo.savePreference(
      const CalendarPreference(defaultDurationMinutes: 90),
    );
    final pref = await repo.watchPreference().first;
    expect(pref.revision, 2);
    expect(pref.defaultDurationMinutes, 90);
    final rows = await db.select(db.calendarPreferences).get();
    expect(rows, hasLength(1));
  });

  // TC-CAL-KR-506：默认日历唯一 —— setDefault 两次不同 id，只有后者 isDefault。
  test('TC-CAL-KR-506 默认日历唯一', () async {
    await repo.upsertCalendar(cal(id: 'a'));
    await repo.upsertCalendar(cal(id: 'b'));
    await repo.setDefaultCalendar('a');
    await repo.setDefaultCalendar('b');
    final seen = await repo.watchCalendars().first;
    expect(seen.where((c) => c.isDefault).map((c) => c.id), ['b']);
  });

  // TC-CAL-KR-507：可见性仅此 —— setVisibility(onlyId) 仅该日历 isVisible。
  test('TC-CAL-KR-507 可见性仅此', () async {
    await repo.upsertCalendar(cal(id: 'a'));
    await repo.upsertCalendar(cal(id: 'b'));
    await repo.upsertCalendar(cal(id: 'c'));
    await repo.setVisibility(onlyId: 'b');
    final seen = await repo.watchCalendars().first;
    expect(seen.where((c) => c.isVisible).map((c) => c.id), ['b']);
  });

  // TC-CAL-KR-508：搜索 —— 标题含「牙医」与地点含「牙医」各一条，search 返回 2 条。
  test('TC-CAL-KR-508 搜索', () async {
    await repo.upsertCalendar(cal());
    await repo.upsertEvent(event(id: 't1', title: '牙医复诊'));
    await repo.upsertEvent(event(id: 't2', title: '例会', location: '牙医诊所旁会议室'));
    await repo.upsertEvent(event(id: 't3', title: '无关'));
    final hits = await repo.search('牙医');
    expect(hits.map((e) => e.id).toSet(), {'t1', 't2'});
  });

  // TC-CAL-KR-509：THIS 范围 —— 对第 2 次 scope=thisOnly 改标题：
  // 主记录 exdates 含该次；新例外行标题已改（originalStart=该次）。
  test('TC-CAL-KR-509 THIS 范围', () async {
    await repo.upsertCalendar(cal());
    final master = event(
      id: 'm1',
      title: '站会',
      startAt: DateTime.utc(2026, 11, 1, 9),
      endAt: DateTime.utc(2026, 11, 1, 9, 30),
      rrule: 'FREQ=DAILY',
    );
    await repo.upsertEvent(master);

    await repo.upsertEvent(
      _withTitle(master, '改期'),
      scope: EditScope.thisOnly,
      occurrenceStart: DateTime.utc(2026, 11, 2, 9),
    );

    final got = await repo.getEvent('m1');
    expect(got!.exdates, [DateTime.utc(2026, 11, 2, 9)], reason: '主记录 exdates 含该次');

    final rows = await (db.select(db.calendarEvents)
          ..where((t) => t.parentEventId.equals('m1')))
        .get();
    expect(rows, hasLength(1), reason: '新建例外行');
    final ex = rows.single;
    expect(ex.title, '改期');
    expect(ex.originalStartAt!.toUtc(), DateTime.utc(2026, 11, 2, 9));
    // 仅改标题：例外次时间 = 原始 occurrence 时间（时长保持 30 分钟）
    expect(ex.startAt.toUtc(), DateTime.utc(2026, 11, 2, 9));
    expect(ex.endAt.toUtc(), DateTime.utc(2026, 11, 2, 9, 30));
    expect(ex.rrule, isNull, reason: '例外行不带 rrule');
  });

  // TC-CAL-KR-510：只读日历 —— kind=subscription 上 upsertEvent 抛 StateError，库无新行。
  test('TC-CAL-KR-510 只读日历', () async {
    await repo.upsertCalendar(cal(id: 'sub', title: '订阅', kind: CalendarKind.subscription));
    await expectLater(
      repo.upsertEvent(event(id: 'ro1', calendarId: 'sub')),
      throwsStateError,
    );
    final rows = await db.select(db.calendarEvents).get();
    expect(rows, isEmpty, reason: '库无新行');
  });

  // TC-CAL-UI-125（持久化半）：订阅上次刷新失败信息入列并跨 upsert 覆盖（契约 §2.6 last_refresh_error）。
  test('TC-CAL-UI-125 lastRefreshError 落库往返', () async {
    await repo.upsertCalendar(const Calendar(
      id: 'sub-err',
      title: '失败订阅',
      colorArgb: 0xFFAF52DE,
      kind: CalendarKind.subscription,
      lastRefreshError: '拉取超时',
    ));
    final row = (await db.select(db.calendars).get())
        .singleWhere((c) => c.id == 'sub-err');
    expect(row.lastRefreshError, '拉取超时', reason: '列写入');
    final seen = (await repo.watchCalendars().first)
        .singleWhere((c) => c.id == 'sub-err');
    expect(seen.lastRefreshError, '拉取超时', reason: '读回 kernel 模型');

    await repo.upsertCalendar(const Calendar(
      id: 'sub-err',
      title: '失败订阅',
      colorArgb: 0xFFAF52DE,
      kind: CalendarKind.subscription,
    ));
    final cleared = (await db.select(db.calendars).get())
        .singleWhere((c) => c.id == 'sub-err');
    expect(cleared.lastRefreshError, isNull, reason: '刷新成功后清空');
  });

  // TC-CAL-UI-125（升级半）：v9 老库（无该列）重开时由 V10 迁移补列，旧行仍可写读。
  test('TC-CAL-UI-125 v9 迁移到 v10 补 last_refresh_error 列', () async {
    final dir = await Directory.systemTemp.createTemp('cal_drift_v10');
    final file = File('${dir.path}/legacy_v9.db');
    addTearDown(() => dir.deleteSync(recursive: true));

    // 先用当前类建库并灌一行，再摘掉 V10 新列降回 v9 形态
    final seed = LifeProductivityDb(NativeDatabase(file));
    await seed.into(seed.calendars).insert(CalendarsCompanion.insert(
          id: 'old9',
          title: '旧订阅',
          colorArgb: 0xFFAF52DE,
        ));
    seed.customStatement('ALTER TABLE calendars DROP COLUMN last_refresh_error');
        // V14（flutter#144）：reminder_lists 新增 remote_id；降到 v9 基线
    // 须一并移除，否则重开时 from<14 的加列与现存列冲突（duplicate column）
    seed.customStatement('ALTER TABLE reminder_lists DROP COLUMN remote_id');
    // V16（flutter#278）：reminder_items 新增 created_at；降到 v9 基线同样须移除
    seed.customStatement('ALTER TABLE reminder_items DROP COLUMN created_at');
    seed.customStatement('PRAGMA user_version = 9');
    await seed.close();

    final reopened = LifeProductivityDb(NativeDatabase(file));
    addTearDown(reopened.close);
    final migrated = DriftCalendarRepository(reopened);
    await migrated.upsertCalendar(const Calendar(
      id: 'old9',
      title: '旧订阅',
      colorArgb: 0xFFAF52DE,
      kind: CalendarKind.subscription,
      lastRefreshError: '拉取超时',
    ));
    final seen = (await migrated.watchCalendars().first)
        .singleWhere((c) => c.id == 'old9');
    expect(seen.lastRefreshError, '拉取超时', reason: '迁移补出的列可写读');
  });
}
