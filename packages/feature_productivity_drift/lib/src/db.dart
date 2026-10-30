import 'dart:convert';

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

  /// 服务端清单 ID（flutter#144 / TC-SYNC-106；NULL = 纯本地未同步）。V14。
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 清单手动分区表（V15 / #169；替掉 `reminder_lists.sections_json` 整块列）。
///
/// 一条分区一行：跨设备并发改**同一清单的不同分区**时各写各的行，
/// 不再「读整块 JSON → 改一条 → 写整块」互相覆盖。
/// `sections_json` 保留一版作回滚快照，读取侧不再使用。
class ReminderSections extends Table {
  /// 所属清单（本地 id）。
  TextColumn get listId => text()();

  /// 分区本地 id（同一清单内唯一）。
  TextColumn get id => text()();

  TextColumn get title => text()();

  /// 分区排序（升序；同值按 id 升序兜底）。
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 服务端分区 ID（flutter#144 / TC-SYNC-106；NULL = 纯本地未同步）。
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {listId, id};
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

  /// T-04：重复结束日期（本地日期；null = 永不结束）。
  DateTimeColumn get recurrenceUntil => dateTime().nullable()();

  /// #482：提前提醒时刻（在 dueAt 之前触发；null = 不提前提醒）。
  DateTimeColumn get earlyReminderAt => dateTime().nullable()();

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

  /// 创建时间（服务端 create_time 权威；null = 老数据）。V16（flutter #278）。
  DateTimeColumn get createdAt => dateTime().nullable()();

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

  /// 上次订阅刷新失败的错误信息（NULL=正常；契约 §2.6 last_refresh_error）。
  TextColumn get lastRefreshError => text().nullable()();

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

/// 记录文件夹表（lifeos/note F-02；字段对齐 kernel.NoteFolder，契约 §2）。
class NoteFolders extends Table {
  TextColumn get id => text()();

  /// 服务端实体 ID（null = 纯本地未同步）。
  TextColumn get remoteId => text().nullable()();

  /// 父文件夹 id；null = 根。
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();

  /// 是否智能文件夹。
  BoolColumn get smart => boolean().withDefault(const Constant(false))();

  /// 智能文件夹条件 JSON（仅 smart=true；键见契约 §1）。
  TextColumn get filterJson => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 备忘录表（lifeos/note F-02；字段对齐 kernel.Note，契约 §2）。
///
/// 正文两份：bodyDelta（Quill Delta JSON；锁定时为密文 Base64）与
/// bodyText（纯文本，搜索用；锁定时强制空）。标签存 JSON 数组文本
/// （关联表随 S-06 服务端半定形后再考虑落表，先与 reminder 同口径）。
class Notes extends Table {
  TextColumn get id => text()();

  /// 服务端实体 ID（null = 纯本地未同步）。
  TextColumn get remoteId => text().nullable()();
  TextColumn get folderId => text()();
  TextColumn get title => text()();
  TextColumn get bodyDelta => text().withDefault(const Constant(''))();
  TextColumn get bodyText => text().withDefault(const Constant(''))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  IntColumn get checklistTotal => integer().withDefault(const Constant(0))();
  IntColumn get checklistDone => integer().withDefault(const Constant(0))();

  /// 标签 JSON 数组文本（如 '["工作"]'；空存 '[]'）。
  TextColumn get tagNames => text().withDefault(const Constant('[]'))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 客户端更新时间戳（毫秒）。
  IntColumn get clientUpdatedAt => integer().withDefault(const Constant(0))();

  /// 乐观锁版本。
  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 同步发件箱（flutter#124 卡 2 / TC-SYNC-107、112）。
///
/// 主键取 (entity_type, entity_id)：同一实体的多次编辑合并成一条待推，
/// 幂等键首次入队生成后不再换（服务端按 clientMutationId 去重）。
class TaskOutboxRows extends Table {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();

  /// 变更时刻的实体快照 JSON。
  TextColumn get payloadJson => text()();

  TextColumn get clientMutationId => text()();
  IntColumn get clientUpdatedAt => integer()();

  @override
  Set<Column> get primaryKey => {entityType, entityId};
}

/// 任务域增量游标（flutter#124 卡 3 / TC-SYNC-107「游标前进」的本地半边）。
///
/// 一个域一行：只有「落库成功」的游标才写回，重启后从上次的位置续拉，
/// 而不是每次从头（游标写坏=重复物化或对不齐）。
class SyncCursorRows extends Table {
  TextColumn get domain => text()();
  TextColumn get cursor => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {domain};
}

/// 任务侧本地偏好（flutter#124 卡 4 / TC-UI-120）。
///
/// 照 `CalendarPreferences` 先例：本地单用户一行（`userKey='local'`），
/// `revision` 每次保存 +1；无行时仓库回契约默认且不建行。
class TaskPreferences extends Table {
  TextColumn get userKey => text()();
  TextColumn get defaultListId => text().nullable()();
  BoolColumn get allDayNotify => boolean().withDefault(const Constant(true))();
  BoolColumn get markComplete => boolean().withDefault(const Constant(false))();
  BoolColumn get suggestLists => boolean().withDefault(const Constant(true))();

  /// 徽标数量是否包含「今天到期」（#451；默认 true = 与 #447 的初始口径一致）。
  BoolColumn get badgeIncludesTodayDue =>
      boolean().withDefault(const Constant(true))();

  /// 全天提醒是否按「逾期」显示（#446；默认 false = 与改造前行为一致）。
  BoolColumn get allDayRemindersOverdue =>
      boolean().withDefault(const Constant(false))();

  /// 「今天」汇总通知时点（#445；`HH:mm`，默认 09:00 = Apple 的默认值）。
  TextColumn get todayNotifyTime => text().withDefault(const Constant('09:00'))();

  /// 手动设定的时区（#448；IANA 名，null = 跟随系统）。
  TextColumn get manualTimeZone => text().nullable()();

  /// 视图态（卡 4b）：显示已完成 / 排序模式 / 侧栏显隐 / 折叠键 JSON 数组。
  BoolColumn get showCompleted =>
      boolean().withDefault(const Constant(false))();
  TextColumn get sortMode => text().withDefault(const Constant('manual'))();
  BoolColumn get sidebarVisible => boolean().withDefault(const Constant(true))();
  TextColumn get collapsedKeysJson =>
      text().withDefault(const Constant('[]'))();

  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {userKey};
}

/// 记录侧本地偏好（#394 / TC-NOTE-UI-111）。
///
/// 照 `TaskPreferences` 先例：本地单用户一行（`userKey='local'`），`revision`
/// 每次保存 +1；无行时仓库回契约默认且不建行。
class NotePreferences extends Table {
  TextColumn get userKey => text()();

  /// 新备忘录默认保存到的文件夹（null = 跟随当前文件夹）。
  TextColumn get defaultFolderId => text().nullable()();

  /// 排序档位名（`custom`/`title`/`updated`）。
  TextColumn get sortMode => text().withDefault(const Constant('custom'))();

  /// 列表按日期分组（#392，Apple「按日期分组备忘录」）。默认 true = 老用户升级后
  /// 列表样子不变（V17 起就一直分组着）。
  BoolColumn get groupByDate => boolean().withDefault(const Constant(true))();

  /// 新备忘录开头格式档位名（#392，Apple「新备忘录开头格式」弹出菜单）。
  TextColumn get beginWith => text().withDefault(const Constant('nothing'))();

  /// 默认正文文本大小（#463，Apple「默认文本大小」滑块）。存磅值 13..24。
  IntColumn get defaultTextSize => integer().withDefault(const Constant(16))();

  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {userKey};
}

@DriftDatabase(
    tables: [ReminderLists, ReminderSections, ReminderItems, Calendars, CalendarEvents, CalendarPreferences, NoteFolders, Notes, TaskOutboxRows, SyncCursorRows, TaskPreferences, NotePreferences])
class LifeProductivityDb extends _$LifeProductivityDb {
  LifeProductivityDb(super.e);

  @override
  int get schemaVersion => 23;

  /// 幂等加列（#451/#446 共用）。
  ///
  /// 两个坑都踩过：迁移链测试先按「当前 schema」建表再回放迁移 → `duplicate column`；
  /// 手搓的最小旧库没有该表 → `no such table`。所以先探测再动。
  Future<void> _addColumnIfTableExists(
    Migrator m,
    String table,
    TableInfo tableInfo,
    GeneratedColumn<Object> column,
  ) async {
    final tables = await m.database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          variables: [Variable.withString(table)],
        )
        .get();
    if (tables.isEmpty) return;
    final columns =
        await m.database.customSelect("PRAGMA table_info('$table')").get();
    final name = column.name;
    if (columns.any((row) => row.data['name'] == name)) return;
    await m.addColumn(tableInfo, column);
  }

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
          if (from <= 7 && to >= 8) {
            // V8（T-04 / TC-UI-319）：重复结束日期
            await m.addColumn(reminderItems, reminderItems.recurrenceUntil);
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
          if (from < 9) {
            // V9（lifeos/note F-02 / TC-NOTE-KR-101）：记录两表 + 文件夹排序索引
            await m.createTable(noteFolders);
            await m.createTable(notes);
            await m.createIndex(
              Index('idx_notes_folder', 'CREATE INDEX IF NOT EXISTS idx_notes_folder '
                  'ON notes (folder_id, sort_order)'),
            );
          }
          if (from >= 7 && from < 10) {
            // V10（lifeos/calendar F-16 / TC-CAL-UI-125）：订阅上次刷新失败信息
            // 从 <7 升级时 calendars 表由上面 createTable 建成，已含该列，故不重复加。
            await m.addColumn(calendars, calendars.lastRefreshError);
          }
          if (from < 11) {
            // V11（flutter#124 卡 2 / TC-SYNC-107、112）：同步发件箱
            await m.createTable(taskOutboxRows);
            await m.createIndex(
              Index('idx_task_outbox_due',
                  'CREATE INDEX IF NOT EXISTS idx_task_outbox_due '
                  'ON task_outbox_rows (client_updated_at, entity_id)'),
            );
          }
          if (from < 12) {
            // V12（flutter#124 卡 3 / TC-SYNC-106、107）：增量游标持久化
            await m.createTable(syncCursorRows);
          }
          if (from < 13) {
            // V13（flutter#124 卡 4 / TC-UI-120）：任务侧本地偏好
            await m.createTable(taskPreferences);
          }
          if (from < 14 && to >= 14) {
            // V14（flutter#144 / TC-SYNC-106）：清单入站落库要有服务端 ID 列。
            // to 上界必须有：迁移测试会在「已按最新 schema 建好的库」上重放
            // 历史 onUpgrade(from, to)，缺上界就对已有列重复 ADD COLUMN。
            await m.addColumn(reminderLists, reminderLists.remoteId);
            await m.createIndex(
              Index('idx_lists_remote', 'CREATE INDEX idx_lists_remote '
                  'ON reminder_lists (remote_id)'),
            );
          }
          if (from < 15 && to >= 15) {
            // V15（#169 / TC-SYNC-106、TC-KR-118）：分区从整块 JSON 列拆成
            // 一行一个分区。旧列保留一版（回滚快照），这里把既有数据搬进新表。
            await m.createTable(reminderSections);
            await m.createIndex(
              Index('idx_sections_list_order',
                  'CREATE INDEX IF NOT EXISTS idx_sections_list_order '
                  'ON reminder_sections (list_id, sort_order)'),
            );
            await _backfillSections(m);
          }
          if (from < 16 && to >= 16) {
            // V16（flutter #278 / Apple mac/13 四档排序）：任务创建时间落列。
            // 存量行留 null（服务端没回溯过创建时间），排序时排最后而不是瞎猜。
            await m.addColumn(reminderItems, reminderItems.createdAt);
          }
          if (from < 22 && to >= 22) {
            // V22（flutter #392 / TC-NOTE-UI-111）：设置页补 Apple 的两条可比条目
            // ——「按日期分组备忘录」勾选与「新备忘录开头格式」弹出菜单。
            // 默认 true/nothing = 老用户升级后列表样子与新建行为都不变。
            await _addColumnIfTableExists(m, 'note_preferences',
                notePreferences, notePreferences.groupByDate);
            await _addColumnIfTableExists(m, 'note_preferences',
                notePreferences, notePreferences.beginWith);
          }
          if (from < 22 && to >= 22) {
            // V22（flutter #463）：默认文本大小。16 磅 = 与改造前渲染等价。
            await _addColumnIfTableExists(m, 'note_preferences',
                notePreferences, notePreferences.defaultTextSize);
          }

          if (from < 23 && to >= 23) {
            // #519：旧库夹具可能没有 reminder_items 表，沿用既有「缺表跳过」守卫。
            await _addColumnIfTableExists(m, 'reminder_items', reminderItems,
                reminderItems.earlyReminderAt);
          }
          if (from < 21 && to >= 21) {
            // V21（flutter #448）：手动设定时区（null = 跟随系统，与改造前一致）。
            await _addColumnIfTableExists(m, 'task_preferences',
                taskPreferences, taskPreferences.manualTimeZone);
          }

          if (from < 20 && to >= 20) {
            // V20（flutter #445）：「今天」汇总通知时点。默认 09:00 与 Apple 一致。
            await _addColumnIfTableExists(m, 'task_preferences',
                taskPreferences, taskPreferences.todayNotifyTime);
          }

          if (from < 19 && to >= 19) {
            // V19（flutter #446）：全天提醒是否显示为逾期。
            // 默认 false = 老用户升级后行为不变。
            await _addColumnIfTableExists(m, 'task_preferences',
                taskPreferences, taskPreferences.allDayRemindersOverdue);
          }

          if (from < 18 && to >= 18) {
            // V18（flutter #451）：徽标「含今天到期」开关。
            // 默认 true = 老用户升级后行为不变（不因升级丢徽标）。
            //
            // **幂等**：迁移链测试会先按「当前 schema」建表再回放迁移，此时列已存在；
            // 直接 addColumn 会抛 `duplicate column name`。先查一次 PRAGMA。
            await _addColumnIfTableExists(m, 'task_preferences',
                taskPreferences, taskPreferences.badgeIncludesTodayDue);
          }

          if (from < 17 && to >= 17) {
            // V17（flutter #394 / TC-NOTE-UI-111）：记录设置此前只活在内存里，
            // 重启即回默认值——给它一张自己的偏好表（照任务/日历先例）。
            await m.createTable(notePreferences);
          }
        },
      );

  /// V15 数据搬迁：`reminder_lists.sections_json` → `reminder_sections` 行。
  ///
  /// 单条坏 JSON 不能拖垮整库升级：逐清单解析，解析失败的清单跳过（读取侧
  /// 退化成「无分区」，用户下一次分区写入即可自愈）。
  static Future<void> _backfillSections(Migrator m) async {
    final rows = await m.database
        .customSelect('SELECT id, sections_json FROM reminder_lists')
        .get();
    for (final row in rows) {
      final listId = row.data['id'] as String;
      final raw = row.data['sections_json'] as String?;
      if (raw == null || raw.isEmpty) continue;
      final List<dynamic> decoded;
      try {
        final parsed = jsonDecode(raw);
        if (parsed is! List) continue;
        decoded = parsed;
      } catch (_) {
        continue;
      }
      for (final entry in decoded.whereType<Map>()) {
        final id = entry['id'];
        if (id is! String) continue;
        await m.database.customStatement(
          'INSERT OR REPLACE INTO reminder_sections '
          '(list_id, id, title, sort_order, remote_id) VALUES (?, ?, ?, ?, ?)',
          [
            listId,
            id,
            entry['title'] as String? ?? '',
            (entry['sortOrder'] as num?)?.toInt() ?? 0,
            entry['remoteId'] as String?,
          ],
        );
      }
    }
  }
}
