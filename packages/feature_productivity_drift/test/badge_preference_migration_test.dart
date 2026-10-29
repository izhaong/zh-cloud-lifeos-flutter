// #451：徽标「含今天到期」设置的 v17→v18 迁移。
//
// 关键约束（写清）：**老用户升级后行为不变**——新列默认 true，不因升级丢徽标。
import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

void main() {
  test('#451 全新库：schema 18 且默认 true', () async {
    final db = LifeProductivityDb(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 20);
    // 默认值体现在「插入时」而非「查询时」：
    final repo = DriftTaskPreferenceRepository(db);
    await repo.savePreference(const TaskPreference());
    final saved = await repo.watchPreference().first;
    expect(saved.badgeIncludesTodayDue, isTrue);
  });

  test('#451 v17 旧库升级到 v18：老数据保留、新列默认 true', () async {
    final raw = sq.sqlite3.openInMemory();
    // 手搓 v17 的 task_preferences（无新列）+ 一行老数据
    raw.execute('''
      CREATE TABLE task_preferences (
        user_key TEXT NOT NULL PRIMARY KEY,
        default_list_id TEXT,
        all_day_notify INTEGER NOT NULL DEFAULT 1,
        mark_complete INTEGER NOT NULL DEFAULT 0,
        suggest_lists INTEGER NOT NULL DEFAULT 0,
        show_completed INTEGER NOT NULL DEFAULT 0,
        sort_mode TEXT NOT NULL DEFAULT 'manual',
        sidebar_visible INTEGER NOT NULL DEFAULT 1,
        collapsed_keys_json TEXT NOT NULL DEFAULT '[]',
        revision INTEGER NOT NULL DEFAULT 3
      );
    ''');
    raw.execute('''
      INSERT INTO task_preferences (user_key, suggest_lists, revision)
      VALUES ('local', 0, 3);
    ''');
    raw.execute('PRAGMA user_version = 17;');

    final db = LifeProductivityDb(NativeDatabase.opened(raw));
    addTearDown(db.close);
    // 触发迁移（第一次查询会走 onUpgrade）
    await db.customSelect('SELECT 1').get();
    expect(db.schemaVersion, 20);

    final repo = DriftTaskPreferenceRepository(db);
    final pref = await repo.watchPreference().first;
    expect(pref.badgeIncludesTodayDue, isTrue,
        reason: '老用户升级后徽标口径不能变（默认 true）');
    expect(pref.suggestLists, isFalse, reason: '老数据必须保留（不因迁移被重置）');
    expect(pref.revision, 3);
  });
}
