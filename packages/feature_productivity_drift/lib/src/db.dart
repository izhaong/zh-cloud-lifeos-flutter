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

@DriftDatabase(tables: [ReminderLists, ReminderItems])
class LifeProductivityDb extends _$LifeProductivityDb {
  LifeProductivityDb(super.e);

  @override
  int get schemaVersion => 6;

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
        },
      );
}
