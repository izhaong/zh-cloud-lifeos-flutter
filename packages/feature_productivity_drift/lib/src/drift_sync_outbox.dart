import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;

import 'db.dart';

/// [kernel.SyncOutbox] 的 Drift 实现（flutter#124 卡 2 / TC-SYNC-107、112）。
///
/// - 入队与业务写表在同一事务里由仓库层调用，重启后队列仍在
/// - 同实体未推条目**合并**：载荷取最新、幂等键保留
/// - 回执处理与 `remoteId` 回填同一事务：要么都成，要么都留待续推
class DriftSyncOutbox implements kernel.SyncOutbox {
  DriftSyncOutbox(this._db);

  final LifeProductivityDb _db;

  @override
  Future<void> enqueue(kernel.SyncOutboxEntry entry) {
    return _db.transaction(() async {
      final existing = await _find(entry.entityType, entry.entityId);
      await _db.into(_db.taskOutboxRows).insertOnConflictUpdate(
            TaskOutboxRowsCompanion(
              entityType: Value(entry.entityType),
              entityId: Value(entry.entityId),
              operation: Value(entry.operation),
              payloadJson: Value(jsonEncode(entry.payload)),
              // 幂等键只在首次入队生成；后续编辑沿用（服务端按键去重）
              clientMutationId:
                  Value(existing?.clientMutationId ?? entry.clientMutationId),
              clientUpdatedAt: Value(entry.clientUpdatedAt),
            ),
          );
    });
  }

  @override
  Future<List<kernel.SyncOutboxEntry>> pending() async {
    final rows = await (_db.select(_db.taskOutboxRows)
          ..orderBy([
            (t) => OrderingTerm(expression: t.clientUpdatedAt),
            (t) => OrderingTerm(expression: t.entityId),
          ]))
        .get();
    return [
      for (final r in rows)
        kernel.SyncOutboxEntry(
          entityType: r.entityType,
          entityId: r.entityId,
          operation: r.operation,
          payload: _decode(r.payloadJson),
          clientMutationId: r.clientMutationId,
          clientUpdatedAt: r.clientUpdatedAt,
        ),
    ];
  }

  @override
  Future<void> acknowledge({
    required String entityType,
    required String entityId,
    String? serverId,
  }) {
    return _db.transaction(() async {
      final q = _db.delete(_db.taskOutboxRows);
      q.where((t) => t.entityType.equals(entityType));
      q.where((t) => t.entityId.equals(entityId));
      await q.go();
      if (entityType == 'task' && serverId != null) {
        // 临时 ID 映射收口：本地 UUID 行记下服务端 id，后续编辑直接带它推
        await (_db.update(_db.reminderItems)
              ..where((t) => t.id.equals(entityId)))
            .write(ReminderItemsCompanion(remoteId: Value(serverId)));
      }
    });
  }

  Future<TaskOutboxRow?> _find(String entityType, String entityId) async {
    final q = _db.select(_db.taskOutboxRows);
    q.where((t) => t.entityType.equals(entityType));
    q.where((t) => t.entityId.equals(entityId));
    return q.getSingleOrNull();
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // 损坏快照按空载荷处理：宁可推空载荷，也不让整条队列卡死
    }
    return {};
  }
}

/// [kernel.SyncCursorStore] 的 Drift 实现（flutter#124 卡 3 / TC-SYNC-107）。
///
/// 任务域一个域一行；只有落库成功的游标才写回，重启后从原位续拉。
class DriftSyncCursorStore implements kernel.SyncCursorStore {
  DriftSyncCursorStore(this._db);

  final LifeProductivityDb _db;

  static const domain = 'task';

  @override
  Future<String?> read() async {
    final row = await (_db.select(_db.syncCursorRows)
          ..where((t) => t.domain.equals(domain)))
        .getSingleOrNull();
    return row?.cursor;
  }

  @override
  Future<void> write(String cursor) =>
      _db.into(_db.syncCursorRows).insertOnConflictUpdate(
            SyncCursorRowsCompanion(
              domain: const Value(domain),
              cursor: Value(cursor),
              updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
}
