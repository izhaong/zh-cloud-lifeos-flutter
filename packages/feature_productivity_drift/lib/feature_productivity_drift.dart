import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'src/db.dart';
import 'src/drift_calendar_repository.dart';
import 'src/drift_reminder_repository.dart';

export 'src/db.dart'
    show
        LifeProductivityDb,
        ReminderLists,
        ReminderItems,
        ReminderListsCompanion,
        ReminderItemsCompanion,
        Calendars,
        CalendarEvents,
        CalendarPreferences,
        CalendarsCompanion,
        CalendarEventsCompanion,
        CalendarPreferencesCompanion;
export 'src/drift_calendar_repository.dart';
export 'src/drift_reminder_repository.dart';

/// 打开默认位置（应用文档目录）的 Drift 库。
///
/// 测试一律用 `LifeProductivityDb(NativeDatabase.memory())`，不经本函数。
Future<DriftReminderRepository> openDefaultDriftRepository() async {
  final dir = await getApplicationDocumentsDirectory();
  final db = LifeProductivityDb(
    driftDatabase(name: p.join(dir.path, 'life_productivity.sqlite')),
  );
  return DriftReminderRepository(db);
}

/// 在已打开的库上创建日历仓库（F-02：不改 [openDefaultDriftRepository] 返回类型）。
///
/// 测试一律用 `LifeProductivityDb(NativeDatabase.memory())`，不经本函数。
DriftCalendarRepository openDefaultDriftCalendarRepository(
  LifeProductivityDb db,
) {
  return DriftCalendarRepository(db);
}
