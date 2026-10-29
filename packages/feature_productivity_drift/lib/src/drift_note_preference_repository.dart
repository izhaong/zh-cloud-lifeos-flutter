import 'package:drift/drift.dart' show Value;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;

import 'db.dart';

/// [kernel.NotePreferenceRepository] 的 Drift 实现（flutter#394 / TC-NOTE-UI-111）。
///
/// 照 `DriftTaskPreferenceRepository` 的先例：本地单用户一行、
/// 无行回契约默认（不建行）、`revision` 由本层递增。
class DriftNotePreferenceRepository implements kernel.NotePreferenceRepository {
  DriftNotePreferenceRepository(this._db);

  final LifeProductivityDb _db;

  /// 本地单用户偏好行主键（未登录 F1 Noop 口径）。
  static const String _localUserKey = 'local';

  @override
  Stream<kernel.NotePreference> watchPreference() {
    final query = _db.select(_db.notePreferences)
      ..where((t) => t.userKey.equals(_localUserKey));
    return query.watchSingleOrNull().map(
      (row) => row == null ? kernel.NotePreference.defaults : _model(row),
    );
  }

  @override
  Future<void> savePreference(kernel.NotePreference preference) async {
    final existing = await (_db.select(
      _db.notePreferences,
    )..where((t) => t.userKey.equals(_localUserKey))).getSingleOrNull();
    await _db
        .into(_db.notePreferences)
        .insertOnConflictUpdate(
          NotePreferencesCompanion.insert(
            userKey: _localUserKey,
            defaultFolderId: Value(preference.defaultFolderId),
            sortMode: Value(preference.sortMode),
            revision: Value((existing?.revision ?? 0) + 1),
          ),
        );
  }

  static kernel.NotePreference _model(NotePreference row) =>
      kernel.NotePreference(
        defaultFolderId: row.defaultFolderId,
        sortMode: row.sortMode,
        revision: row.revision,
      );
}
