import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'src/db.dart';
import 'src/drift_reminder_repository.dart';

export 'src/db.dart' show LifeProductivityDb, ReminderLists, ReminderItems;
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
