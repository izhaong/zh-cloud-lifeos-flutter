import 'package:equatable/equatable.dart';

/// 同步变更（客户端 → 服务端 push 载荷单元；契约对齐 Spec 028）。
class SyncChange extends Equatable {
  const SyncChange({
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.payload = const {},
    this.clientMutationId,
    this.clientUpdatedAt,
    this.baseRevision,
  });

  /// `task` / `list` / `task_section` / `tag`。
  final String entityType;

  /// 本地实体 id（离线新建=本地 UUID；服务端回填映射后换 serverId）。
  final String entityId;

  /// `upsert` / `delete`。
  final String operation;

  final Map<String, dynamic> payload;

  /// 幂等键（重放不重复）。
  final String? clientMutationId;

  /// 客户端最后更新时间（冲突「新者胜」比较基准；epoch 毫秒）。
  final int? clientUpdatedAt;

  /// 重推时携带的服务端基线版本（baseRevision 通道；首次推 null）。
  final int? baseRevision;

  Map<String, dynamic> toJson() => {
        'entityType': entityType,
        'entityId': entityId,
        'operation': operation,
        'payload': payload,
        if (clientMutationId != null) 'clientMutationId': clientMutationId,
        if (clientUpdatedAt != null) 'clientUpdatedAt': clientUpdatedAt,
        if (baseRevision != null) 'baseRevision': baseRevision,
      };

  @override
  List<Object?> get props =>
      [entityType, entityId, operation, payload, clientMutationId,
       clientUpdatedAt, baseRevision];
}

/// push 响应（服务端逐 change 回执：serverId 回填/revision/冲突）。
class SyncPushAck extends Equatable {
  const SyncPushAck({
    required this.entityId,
    this.serverId,
    this.revision,
    this.conflict,
  });

  final String entityId;
  final String? serverId;
  final int? revision;

  /// 非 null = 服务端报冲突（REVISION_CONFLICT + serverValue/clientValue）；
  /// 客户端按拍板策略：较新 clientUpdatedAt 整条覆盖后带新 revision 重推。
  final SyncConflict? conflict;

  @override
  List<Object?> get props => [entityId, serverId, revision, conflict];
}

/// 冲突回执（对齐 AppTodoSyncConflictVO：baseRevision 不匹配）。
class SyncConflict extends Equatable {
  const SyncConflict({
    required this.serverRevision,
    this.serverValue,
    this.clientValue,
  });

  final int serverRevision;
  final Map<String, dynamic>? serverValue;
  final Map<String, dynamic>? clientValue;

  @override
  List<Object?> get props => [serverRevision, serverValue, clientValue];
}
