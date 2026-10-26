import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
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
        CalendarPreferencesCompanion,
        NoteFolders,
        Notes,
        NoteFoldersCompanion,
        NotesCompanion;
export 'src/drift_calendar_repository.dart';
export 'src/drift_reminder_repository.dart';

/// 打开默认位置的 Drift 库（提醒与日历仓库共用同一句柄）。
///
/// Web 走 drift 的 WASM 后端（OPFS，浏览器不支持时回落 IndexedDB），资源落在
/// `apps/life_launcher/web/`。两份资源必须与 `pubspec.lock` 钉版同步升级，否则
/// worker 与包内协议不匹配：
/// - `sqlite3.wasm` ← github.com/simolus3/sqlite3.dart release tag `sqlite3-3.5.2`
/// - `drift_worker.js` ← pub 包 drift 2.35.2 根目录的预构建产物
///
/// 测试一律用 `LifeProductivityDb(NativeDatabase.memory())`，不经本函数。
Future<LifeProductivityDb> openDefaultDatabase() async {
  if (kIsWeb) {
    return LifeProductivityDb(
      driftDatabase(
        name: 'life_productivity',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ),
    );
  }
  final dir = await getApplicationDocumentsDirectory();
  return LifeProductivityDb(
    driftDatabase(name: p.join(dir.path, 'life_productivity.sqlite')),
  );
}

/// 打开默认位置（应用文档目录）的提醒仓库。
Future<DriftReminderRepository> openDefaultDriftRepository() async {
  return DriftReminderRepository(await openDefaultDatabase());
}

/// 在已打开的库上创建日历仓库（F-02：不改 [openDefaultDriftRepository] 返回类型）。
///
/// 测试一律用 `LifeProductivityDb(NativeDatabase.memory())`，不经本函数。
DriftCalendarRepository openDefaultDriftCalendarRepository(
  LifeProductivityDb db,
) {
  return DriftCalendarRepository(db);
}
