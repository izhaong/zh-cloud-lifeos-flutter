import 'package:drift/drift.dart';

part 'db.g.dart';

/// 提醒列表表（「我的列表」；智能列表为派生查询，不落表）。
class ReminderLists extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get colorArgb => integer().withDefault(const Constant(0xFF007AFF))();
  BoolColumn get isSmart => boolean().withDefault(const Constant(false))();

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

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ReminderLists, ReminderItems])
class LifeProductivityDb extends _$LifeProductivityDb {
  LifeProductivityDb(super.e);

  @override
  int get schemaVersion => 1;
}
