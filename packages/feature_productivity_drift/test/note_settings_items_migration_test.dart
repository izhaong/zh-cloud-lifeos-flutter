// #392：记录设置新增两格（按日期分组、新备忘录开头格式）的 v21→v22 迁移。
//
// 版本号让位过：这张卡起意时 V20 是空的，落到 develop 时
// #445/#448 已先把 V20/V21 占了，所以本卡的列挂在 V22。
//
// 关键约束：**老用户升级后行为不变**——group_by_date 默认 true（V17 起列表本就
// 分年分组），begin_with 默认 nothing（新建仍是空白正文）。
import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

void main() {
  test('#392 全新库：schema 22 且两格走默认', () async {
    final db = LifeProductivityDb(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 25);
    final repo = DriftNotePreferenceRepository(db);
    await repo.savePreference(const NotePreference());
    final saved = await repo.watchPreference().first;
    expect(saved.groupByDate, isTrue);
    expect(saved.beginWith, 'nothing');
  });

  test('#392 v21 旧库升级到 v22：补齐两格默认值且老数据保留', () async {
    final raw = sq.sqlite3.openInMemory();
    // 手搓 v21 的 note_preferences（无新列）+ 一行老数据。
    // V18~V21 都只动 task_preferences，所以这张表的旧形状就是 V17 建表时的样子。
    raw.execute('''
      CREATE TABLE note_preferences (
        user_key TEXT NOT NULL PRIMARY KEY,
        default_folder_id TEXT,
        sort_mode TEXT NOT NULL DEFAULT 'custom',
        revision INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute('''
      INSERT INTO note_preferences (user_key, default_folder_id, sort_mode, revision)
      VALUES ('local', 'folder.work', 'title', 7);
    ''');
    raw.execute('PRAGMA user_version = 21;');

    final db = LifeProductivityDb(NativeDatabase.opened(raw));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(db.schemaVersion, 25);

    final pref = await DriftNotePreferenceRepository(db).watchPreference().first;
    expect(
      pref.groupByDate,
      isTrue,
      reason: '老用户升级后列表分组样子不能变（默认 true）',
    );
    expect(
      pref.beginWith,
      'nothing',
      reason: '默认空白开头 = 新建备忘录行为与升级前一致',
    );
    expect(pref.defaultFolderId, 'folder.work', reason: '老数据必须保留');
    expect(pref.sortMode, 'title');
    expect(pref.revision, 7);
  });

  test('#392 新格能写回读回（不是只在内存里改）', () async {
    final db = LifeProductivityDb(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftNotePreferenceRepository(db);

    await repo.savePreference(
      const NotePreference().copyWith(groupByDate: false, beginWith: 'checklist'),
    );
    final pref = await repo.watchPreference().first;
    expect(pref.groupByDate, isFalse);
    expect(pref.beginWith, 'checklist');
  });
}
