// #448：手动时区的 v20→v21 迁移。
import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

void main() {
  test('#448 全新库：默认 null（跟随系统）', () async {
    final db = LifeProductivityDb(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 25);
    final repo = DriftTaskPreferenceRepository(db);
    await repo.savePreference(const TaskPreference());
    final saved = await repo.watchPreference().first;
    expect(saved.manualTimeZone, isNull);
  });

  test('#448 v20 旧库升级到 v21：老数据保留、时区默认 null', () async {
    final raw = sq.sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE task_preferences (
        user_key TEXT NOT NULL PRIMARY KEY,
        default_list_id TEXT,
        all_day_notify INTEGER NOT NULL DEFAULT 1,
        mark_complete INTEGER NOT NULL DEFAULT 0,
        suggest_lists INTEGER NOT NULL DEFAULT 0,
        badge_includes_today_due INTEGER NOT NULL DEFAULT 0,
        all_day_reminders_overdue INTEGER NOT NULL DEFAULT 1,
        today_notify_time TEXT NOT NULL DEFAULT '18:30',
        show_completed INTEGER NOT NULL DEFAULT 0,
        sort_mode TEXT NOT NULL DEFAULT 'manual',
        sidebar_visible INTEGER NOT NULL DEFAULT 1,
        collapsed_keys_json TEXT NOT NULL DEFAULT '[]',
        revision INTEGER NOT NULL DEFAULT 9
      );
    ''');
    raw.execute('''
      INSERT INTO task_preferences
        (user_key, suggest_lists, today_notify_time, revision)
      VALUES ('local', 0, '18:30', 9);
    ''');
    raw.execute('PRAGMA user_version = 20;');

    final db = LifeProductivityDb(NativeDatabase.opened(raw));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(db.schemaVersion, 25);

    final repo = DriftTaskPreferenceRepository(db);
    final pref = await repo.watchPreference().first;
    expect(pref.manualTimeZone, isNull, reason: '默认跟随系统，行为不变');
    expect(pref.todayNotifyTime, '18:30', reason: '既有设置保留');
    expect(pref.suggestLists, isFalse);
    expect(pref.revision, 9);
  });

  test('#448 存了时区能读回（往返）', () async {
    final db = LifeProductivityDb(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftTaskPreferenceRepository(db);

    await repo.savePreference(
      const TaskPreference(manualTimeZone: 'Asia/Shanghai'),
    );
    expect((await repo.watchPreference().first).manualTimeZone, 'Asia/Shanghai');

    // 清除（回到跟随系统）
    await repo.savePreference(
      TaskPreference.defaults.copyWith(clearManualTimeZone: true),
    );
    expect((await repo.watchPreference().first).manualTimeZone, isNull);
  });
}
