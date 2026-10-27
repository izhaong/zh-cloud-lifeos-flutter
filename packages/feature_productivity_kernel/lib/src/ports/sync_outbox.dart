import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../models/reminder_item.dart';

/// 发件箱条目（本地已发生、尚未被服务端接受的变更）。
///
/// `clientMutationId` 在**入队时**生成并从此固定：同实体的后续编辑只更新载荷，
/// 不换键——服务端按幂等键去重，断网重推与合并批都必须沿用同一个键（TC-SYNC-108）。
@immutable
final class SyncOutboxEntry extends Equatable {
  const SyncOutboxEntry({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.clientMutationId,
    required this.clientUpdatedAt,
  });

  /// `task`（本卡只任务域；`list`/`task_section` 待列表侧有 remoteId 后接）。
  final String entityType;

  /// 本地实体 id（离线新建即本地 UUID，服务端经临时 ID 映射认它）。
  final String entityId;

  /// `upsert` / `delete`。
  final String operation;

  /// 变更时刻的实体快照（键名对齐服务端 `LifeosTaskSyncCodec.taskPayload`）。
  final Map<String, dynamic> payload;

  /// 幂等键（入队生成，重放不换）。
  final String clientMutationId;

  /// 入队时刻（epoch 毫秒）；同实体多次编辑取最新，出队按此升序。
  final int clientUpdatedAt;

  @override
  List<Object?> get props =>
      [entityType, entityId, operation, payload, clientMutationId, clientUpdatedAt];
}

/// 同步发件箱端口：本地写入与「待推队列」同事务落库，重启不丢（flutter#124 卡 2）。
abstract interface class SyncOutbox {
  /// 登记一条变更；同 (entityType, entityId) 已有未推条目时**合并**
  /// （载荷与 operation 取最新，幂等键保留）。
  Future<void> enqueue(SyncOutboxEntry entry);

  /// 待推条目，按 [SyncOutboxEntry.clientUpdatedAt] 升序（同刻按 entityId）。
  Future<List<SyncOutboxEntry>> pending();

  /// 服务端已处置该变更 → 出队。
  ///
  /// [serverId] 非空时同时把本地实体的 `remoteId` 回填（TC-SYNC-112 临时 ID 映射收口）；
  /// 冲突让位（接受服务端值）调用时不传 serverId，只清队不改写。
  Future<void> acknowledge({
    required String entityType,
    required String entityId,
    String? serverId,
  });
}

/// 提醒条目 → 任务域同步载荷（服务端 push/pull 两侧读的就是这套键名）。
///
/// 日期一律 epoch 毫秒（`LifeosTaskSyncCodec.epochMilli` 同口径）；
/// `isFlagged` 双键（camel + snake）沿用 Todo 线 TC-API-103 的拼写兼容。
Map<String, dynamic> taskSyncPayload(ReminderItem item) => {
      'id': item.id,
      'listId': item.listId,
      'sectionId': item.sectionId,
      'parentTaskId': item.parentId,
      'title': item.title,
      'description': item.notes,
      'notes': item.notes,
      'dueAt': _epochMilli(item.dueAt),
      'priority': item.priority,
      'isFlagged': item.isFlagged,
      'is_flagged': item.isFlagged,
      'isCompleted': item.isCompleted,
      'completedAt': _epochMilli(item.completedAt),
      'sortOrder': item.sortOrder,
      'deletedAt': _epochMilli(item.deletedAt),
      'tags': item.tags,
      'recurrence': item.recurrence,
    };

int? _epochMilli(DateTime? value) => value?.toUtc().millisecondsSinceEpoch;
