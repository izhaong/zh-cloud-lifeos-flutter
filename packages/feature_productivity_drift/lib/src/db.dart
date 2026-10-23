import 'package:drift/drift.dart';

part 'db.g.dart';

/// 提醒列表表（「我的列表」；智能列表为派生查询，不落表）。
class ReminderLists extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get colorArgb => integer().withDefault(const Constant(0xFF007AFF))();
  BoolColumn get isSmart => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

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
  int get schemaVersion => 2;

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
        },
      );
}
