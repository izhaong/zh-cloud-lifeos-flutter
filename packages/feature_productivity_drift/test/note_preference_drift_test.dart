import 'package:drift/native.dart';

import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-111 的持久半边（flutter#394）：记录设置要能落库并重启读回。
///
/// 照 `task_preference_drift_test.dart` 的口径：V17 建表、无行回契约默认、
/// 一用户一行、`revision` 由仓库递增。
void main() {
  late LifeProductivityDb db;
  late DriftNotePreferenceRepository repo;

  setUp(() {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftNotePreferenceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('V17：note_preferences 建表，schemaVersion 到 17', () async {
    expect(db.schemaVersion, 24);
    final names =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type='table'",
                )
                .get())
            .map((r) => r.read<String>('name'))
            .toSet();
    expect(names.contains('note_preferences'), isTrue);
  });

  test('无行时回契约默认且不建行（默认文件夹未设、排序 custom）', () async {
    final p = await repo.watchPreference().first;
    expect(p, NotePreference.defaults);
    expect(p.defaultFolderId, isNull);
    expect(p.sortMode, 'custom');
    final rows = await db.select(db.notePreferences).get();
    expect(rows, isEmpty, reason: 'GET 不建行（与任务/日历偏好同口径）');
  });

  test('保存后回读新值、revision 递增、仍只有一行', () async {
    await repo.savePreference(
      const NotePreference(defaultFolderId: 'folder.work', sortMode: 'title'),
    );

    final saved = await repo.watchPreference().first;
    expect(saved.defaultFolderId, 'folder.work');
    expect(saved.sortMode, 'title');
    expect(saved.revision, 1, reason: '首存 = 空行 0 + 1');

    await repo.savePreference(saved.copyWith(sortMode: 'updated'));
    final again = await repo.watchPreference().first;
    expect(again.revision, 2);
    expect(again.sortMode, 'updated');
    expect(again.defaultFolderId, 'folder.work', reason: '没改的字段要保持');

    final rows = await db.select(db.notePreferences).get();
    expect(rows, hasLength(1), reason: '一个本地用户一行，重放覆盖不追加');
  });

  test('默认文件夹可清空（跟随当前文件夹是可达的一档）', () async {
    await repo.savePreference(
      const NotePreference(defaultFolderId: 'folder.work'),
    );
    await repo.savePreference(NotePreference.defaults);

    final back = await repo.watchPreference().first;
    expect(back.defaultFolderId, isNull, reason: '「未设置」要真能写回 null，而不是留着旧值');
    expect(back.revision, 2);
  });

  test('档位串原样存取（归一在 feature_note 解码侧，仓库不猜）', () async {
    await repo.savePreference(const NotePreference(sortMode: 'notARealMode'));
    final back = await repo.watchPreference().first;
    expect(back.sortMode, 'notARealMode');
    expect(back.defaultFolderId, isNull, reason: '没写的那格保持未设');
  });

  test('写一次就广播新值（设置页不手动 reload）', () async {
    final values = <String>[];
    final done = Future<void>(() async {
      while (values.length < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    final sub = repo.watchPreference().listen((p) => values.add(p.sortMode));
    await repo.savePreference(const NotePreference(sortMode: 'title'));
    await done.timeout(const Duration(seconds: 5));
    await sub.cancel();

    expect(values, ['custom', 'title']);
  });
}
