// #445：「今天」汇总通知时点的 v19→v20 迁移。
import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

void main() {
  test('#445 全新库：默认 09:00', () async {
    final db = LifeProductivityDb(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 25);
    final repo = DriftTaskPreferenceRepository(db);
    await repo.savePreference(const TaskPreference());
    final saved = await repo.watchPreference().first;
    expect(saved.todayNotifyTime, '09:00');
    expect(saved.todayNotifyHourMinute, (9, 0));
  });

  test('#445 v19 旧库升级到 v20：老数据保留、时点默认 09:00', () async {
    final raw = sq.sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE task_preferences (
        user_key TEXT NOT NULL PRIMARY KEY,
        default_list_id TEXT,
        all_day_notify INTEGER NOT NULL DEFAULT 0,
        mark_complete INTEGER NOT NULL DEFAULT 0,
        suggest_lists INTEGER NOT NULL DEFAULT 0,
        badge_includes_today_due INTEGER NOT NULL DEFAULT 0,
        all_day_reminders_overdue INTEGER NOT NULL DEFAULT 1,
        show_completed INTEGER NOT NULL DEFAULT 0,
        sort_mode TEXT NOT NULL DEFAULT 'due',
        sidebar_visible INTEGER NOT NULL DEFAULT 0,
        collapsed_keys_json TEXT NOT NULL DEFAULT '[]',
        revision INTEGER NOT NULL DEFAULT 7
      );
    ''');
    raw.execute('''
      INSERT INTO task_preferences
        (user_key, suggest_lists, all_day_reminders_overdue, revision)
      VALUES ('local', 0, 1, 7);
    ''');
    raw.execute('PRAGMA user_version = 19;');

    final db = LifeProductivityDb(NativeDatabase.opened(raw));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(db.schemaVersion, 25);

    final repo = DriftTaskPreferenceRepository(db);
    final pref = await repo.watchPreference().first;
    expect(pref.todayNotifyTime, '09:00', reason: '与 Apple 默认一致');
    expect(pref.allDayRemindersOverdue, isTrue, reason: '既有设置保留');
    expect(pref.suggestLists, isFalse);
    expect(pref.revision, 7);
  });
}
