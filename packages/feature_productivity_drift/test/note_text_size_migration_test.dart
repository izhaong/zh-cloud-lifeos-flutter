// #463：默认文本大小的 v21→v22 迁移。
import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

void main() {
  test('#463 全新库：默认 16 磅', () async {
    final db = LifeProductivityDb(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 23);
    final repo = DriftNotePreferenceRepository(db);
    await repo.savePreference(const NotePreference());
    expect((await repo.watchPreference().first).defaultTextSize, 16);
  });

  test('#463 v21 旧库升级：既有设置保留、新列默认 16', () async {
    final raw = sq.sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE note_preferences (
        user_key TEXT NOT NULL PRIMARY KEY,
        default_folder_id TEXT,
        sort_mode TEXT NOT NULL DEFAULT 'title',
        group_by_date INTEGER NOT NULL DEFAULT 0,
        begin_with TEXT NOT NULL DEFAULT 'body',
        revision INTEGER NOT NULL DEFAULT 4
      );
    ''');
    raw.execute('''
      INSERT INTO note_preferences (user_key, sort_mode, group_by_date, begin_with, revision)
      VALUES ('local', 'title', 0, 'body', 4);
    ''');
    raw.execute('PRAGMA user_version = 21;');

    final db = LifeProductivityDb(NativeDatabase.opened(raw));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(db.schemaVersion, 23);

    final pref = await DriftNotePreferenceRepository(db).watchPreference().first;
    expect(pref.defaultTextSize, 16, reason: '与改造前渲染等价');
    expect(pref.sortMode, 'title', reason: '既有设置保留');
    expect(pref.groupByDate, isFalse);
    expect(pref.beginWith, 'body');
    expect(pref.revision, 4);
  });
}
