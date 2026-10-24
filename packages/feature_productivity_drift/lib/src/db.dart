import 'package:drift/drift.dart';

part 'db.g.dart';

/// 提醒列表表（「我的列表」；智能列表为派生查询，不落表）。
class ReminderLists extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get colorArgb => integer().withDefault(const Constant(0xFF007AFF))();
  BoolColumn get isSmart => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 手动分区元数据 JSON（[{id,title,sortOrder}]；TC-KR-118）。
  /// nullable：V3→V4 增列时旧行为 NULL，读取侧兜底空分区。
  TextColumn get sectionsJson =>
      text().nullable().withDefault(const Constant('[]'))();

  /// 列表分组名（TC-UI-118；NULL = 不分组）。
  TextColumn get groupName => text().nullable()();

  /// 清单类型（TC-UI-115；NULL/standard=标准；grocery=采购）。
  TextColumn get listType => text().nullable()();

  /// 自定义智能列表条件 JSON（TC-UI-116；NULL = 非自定义智能列表）。
  TextColumn get smartFilter => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 提醒条目表。
class ReminderItems extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isFlagged => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();

  /// 标签（JSON 数组文本，如 '["工作","设计"]'；空数组存 '[]'）。
  TextColumn get tags => text().withDefault(const Constant('[]'))();

  /// 重复规则 id（见 kernel Recurrence；null = 不重复）。
  TextColumn get recurrence => text().nullable()();

  /// 子任务的父提醒 id；null = 顶层。
  TextColumn get parentId => text().nullable()();

  /// 同层排序键。
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 服务端实体 ID（Spec 028；null = 纯本地未同步）。V3（Issue #3）。
  TextColumn get remoteId => text().nullable()();

  /// 完成时间（服务端 completedAt 对齐）。V3（Issue #3）。
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// 列表内手动分区 id（A15；跨列表移动时清空）。V3（Issue #3）。
  TextColumn get sectionId => text().nullable()();

  /// 进入最近删除的时间（A10 本地回收窗；null = 未删）。V3（Issue #3）。
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (parent_id) REFERENCES reminder_items(id) ON DELETE CASCADE',
      ];
}

/// 日历表（lifeos/calendar F-02；字段对齐 kernel.Calendar，契约 §5.3）。
class Calendars extends Table {
  TextColumn get id => text()();

  /// 服务端实体 ID（null = 纯本地未同步）。
  TextColumn get remoteId => text().nullable()();
  TextColumn get title => text()();
  IntColumn get colorArgb => integer()();

  /// LOCAL / SUBSCRIPTION / HOLIDAY / SHARED（服务端大写枚举 id）。
  TextColumn get kind => text().withDefault(const Constant('LOCAL'))();
  TextColumn get groupName => text().nullable()();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get ignoreAlerts => boolean().withDefault(const Constant(false))();

  /// kind=subscription 的 .ics 地址。
  TextColumn get sourceUrl => text().nullable()();

  /// 订阅刷新间隔分钟（NULL=手动）。
  IntColumn get refreshMinutes => integer().nullable()();

  /// kind=holiday 的地区码（首期 CN）。
  TextColumn get holidayRegion => text().nullable()();

  /// OWNER / EDIT / VIEW。
  TextColumn get permission => text().withDefault(const Constant('OWNER'))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 日程表（主记录与例外行共用；契约 §5.3：alerts/invitees/exdates 走 JSON 列）。
@TableIndex(name: 'idx_calendar_events_cal_start', columns: {#calendarId, #startAt})
class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get calendarId => text()();
  TextColumn get uid => text()();
  TextColumn get title => text()();
  TextColumn get location => text().nullable()();
  TextColumn get url => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// UTC；全天事件存该日 00:00 创建时区对应 UTC。
  DateTimeColumn get startAt => dateTime()();

  /// UTC 排他；全天事件为次日 00:00。
  DateTimeColumn get endAt => dateTime()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get timeZone => text()();
  BoolColumn get isFloating => boolean().withDefault(const Constant(false))();

  /// RFC 5545 RRULE（不含 `RRULE:` 前缀）；NULL = 不重复。
  TextColumn get rrule => text().nullable()();

  /// 已删除单次出现（ISO UTC 数组文本，如 '["2026-11-03T09:00:00Z"]'）。
  TextColumn get exdatesJson => text().withDefault(const Constant('[]'))();

  /// 非空 = 本行是某重复事件的例外实例。
  TextColumn get parentEventId => text().nullable()();
  DateTimeColumn get originalStartAt => dateTime().nullable()();

  /// CONFIRMED / TENTATIVE / CANCELLED。
  TextColumn get status => text().withDefault(const Constant('CONFIRMED'))();

  /// BUSY / FREE（Apple「显示为」）。
  TextColumn get availability => text().withDefault(const Constant('BUSY'))();
  IntColumn get travelMinutes => integer().nullable()();
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();

  /// 提醒 JSON：[{offsetMinutes?,allDayOffsetDays?,allDayTime?}]。
  TextColumn get alertsJson => text().withDefault(const Constant('[]'))();

  /// 受邀者 JSON：[{memberUserId,displayName,role,partstat,comment,...}]。
  TextColumn get inviteesJson => text().withDefault(const Constant('[]'))();
  IntColumn get sequence => integer().withDefault(const Constant(0))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 日历用户偏好表（单行；userKey='local'；字段对齐契约 §2.9 默认值）。
class CalendarPreferences extends Table {
  TextColumn get userKey => text()();
  TextColumn get defaultCalendarId => text().nullable()();
  IntColumn get startWeekOn => integer().withDefault(const Constant(1))();
  IntColumn get weekViewDays => integer().withDefault(const Constant(7))();
  IntColumn get dayStartHour => integer().withDefault(const Constant(8))();
  IntColumn get dayEndHour => integer().withDefault(const Constant(18))();
  IntColumn get hoursShown => integer().withDefault(const Constant(12))();
  BoolColumn get showDeclinedEvents =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get timeZoneSupport => boolean().withDefault(const Constant(false))();
  TextColumn get displayTimeZone => text().nullable()();
  IntColumn get defaultAlertTimedMinutes => integer().nullable()();
  IntColumn get defaultAlertAllDayDays => integer().nullable()();
  TextColumn get defaultAlertAllDayTime =>
      text().withDefault(const Constant('09:00'))();
  IntColumn get defaultDurationMinutes =>
      integer().withDefault(const Constant(60))();
  TextColumn get alternateCalendar =>
      text().withDefault(const Constant('NONE'))();
  BoolColumn get showWeekNumbers => boolean().withDefault(const Constant(false))();
  BoolColumn get weekViewStartsToday =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get showHolidays => boolean().withDefault(const Constant(true))();
  BoolColumn get openEventsInWindow =>
      boolean().withDefault(const Constant(false))();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {userKey};
}

@DriftDatabase(
    tables: [ReminderLists, ReminderItems, Calendars, CalendarEvents, CalendarPreferences])
class LifeProductivityDb extends _$LifeProductivityDb {
  LifeProductivityDb(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from == 1 && to >= 2) {
            // V2：D6 字段齐备（tags/recurrence/parentId/sortOrder + 列表排序）
            await m.addColumn(
                reminderItems, reminderItems.tags);
            await m.addColumn(
                reminderItems, reminderItems.recurrence);
            await m.addColumn(
                reminderItems, reminderItems.parentId);
            await m.addColumn(
                reminderItems, reminderItems.sortOrder);
            await m.addColumn(reminderLists, reminderLists.sortOrder);
            await m.createIndex(
                Index('idx_items_parent', 'CREATE INDEX idx_items_parent '
                    'ON reminder_items (parent_id)'),
            );
            await m.createIndex(
                Index('idx_items_list_sort', 'CREATE INDEX '
                    'idx_items_list_sort ON reminder_items (list_id, '
                    'sort_order)'),
            );
          }
          if (from <= 2 && to >= 3) {
            // V3（Issue #3 / M2）：服务端契约对齐四列
            await m.addColumn(reminderItems, reminderItems.remoteId);
            await m.addColumn(reminderItems, reminderItems.completedAt);
            await m.addColumn(reminderItems, reminderItems.sectionId);
            await m.addColumn(reminderItems, reminderItems.deletedAt);
            await m.createIndex(
              Index('idx_items_remote', 'CREATE INDEX idx_items_remote '
                  'ON reminder_items (remote_id)'),
            );
          }
          if (from <= 3 && to >= 4) {
            // V4（Issue #2 / M2）：手动分区元数据（TC-KR-118）
            await m.addColumn(reminderLists, reminderLists.sectionsJson);
          }
          if (from <= 4 && to >= 5) {
            // V5（Issue #2 / M2）：列表分组（TC-UI-118，降级=列表分组）
            await m.addColumn(reminderLists, reminderLists.groupName);
          }
          if (from <= 5 && to >= 6) {
            // V6（Issue #2 / M2）：清单类型 + 自定义智能列表条件
            await m.addColumn(reminderLists, reminderLists.listType);
            await m.addColumn(reminderLists, reminderLists.smartFilter);
          }
          if (from < 7) {
            // V7（lifeos/calendar F-02 / TC-CAL-KR-501）：只建三张日历表 + 时间窗索引
            await m.createTable(calendars);
            await m.createTable(calendarEvents);
            await m.createTable(calendarPreferences);
            await m.createIndex(
              Index('idx_calendar_events_cal_start',
                  'CREATE INDEX IF NOT EXISTS idx_calendar_events_cal_start '
                  'ON calendar_events (calendar_id, start_at)'),
            );
          }
        },
      );
}
