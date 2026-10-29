import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;

import 'db.dart';

/// [kernel.TaskPreferenceRepository] 的 Drift 实现（flutter#124 卡 4 / TC-UI-120、308、309）。
///
/// 照 `DriftCalendarRepository` 的偏好先例：本地单用户一行、
/// 无行回契约默认（不建行）、`revision` 由本层递增。
class DriftTaskPreferenceRepository
    implements kernel.TaskPreferenceRepository {
  DriftTaskPreferenceRepository(this._db);

  final LifeProductivityDb _db;

  /// 本地单用户偏好行主键（未登录 F1 Noop 口径）。
  static const String _localUserKey = 'local';

  @override
  Stream<kernel.TaskPreference> watchPreference() {
    final query = _db.select(_db.taskPreferences)
      ..where((t) => t.userKey.equals(_localUserKey));
    return query.watchSingleOrNull().map(
          (row) => row == null
              ? kernel.TaskPreference.defaults
              : _model(row),
        );
  }

  @override
  Future<void> savePreference(kernel.TaskPreference preference) async {
    final existing = await (_db.select(_db.taskPreferences)
          ..where((t) => t.userKey.equals(_localUserKey)))
        .getSingleOrNull();
    await _db.into(_db.taskPreferences).insertOnConflictUpdate(
          TaskPreferencesCompanion.insert(
            userKey: _localUserKey,
            defaultListId: Value(preference.defaultListId),
            allDayNotify: Value(preference.allDayNotify),
            markComplete: Value(preference.markComplete),
            suggestLists: Value(preference.suggestLists),
            badgeIncludesTodayDue:
                Value(preference.badgeIncludesTodayDue),
            allDayRemindersOverdue:
                Value(preference.allDayRemindersOverdue),
            todayNotifyTime: Value(preference.todayNotifyTime),
            showCompleted: Value(preference.showCompleted),
            sortMode: Value(preference.sortMode),
            sidebarVisible: Value(preference.sidebarVisible),
            collapsedKeysJson:
                Value(jsonEncode(preference.collapsedKeys)),
            revision: Value((existing?.revision ?? 0) + 1),
          ),
        );
  }

  static kernel.TaskPreference _model(TaskPreference row) =>
      kernel.TaskPreference(
        defaultListId: row.defaultListId,
        allDayNotify: row.allDayNotify,
        markComplete: row.markComplete,
        suggestLists: row.suggestLists,
        badgeIncludesTodayDue: row.badgeIncludesTodayDue,
        allDayRemindersOverdue: row.allDayRemindersOverdue,
        todayNotifyTime: row.todayNotifyTime,
        showCompleted: row.showCompleted,
        sortMode: row.sortMode,
        sidebarVisible: row.sidebarVisible,
        collapsedKeys: _decodeKeys(row.collapsedKeysJson),
        revision: row.revision,
      );

  /// 损坏的折叠键 JSON 按「没有折叠」处理：视图态缺一点不影响数据可用。
  static List<String> _decodeKeys(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } catch (_) {
      // 忽略
    }
    return const [];
  }
}
