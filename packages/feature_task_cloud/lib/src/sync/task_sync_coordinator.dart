import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;

import 'rest_sync_port.dart';
import 'sync_models.dart';

/// 任务域同步协调器（flutter#124 卡 2 / TC-SYNC-107、108、112）。
///
/// 仓库层把本地变更写进发件箱，这里负责一次成批上送并按回执出队：
/// - 未登录 / 队空 → 直接返回，不发请求、不动队列（TC-SYNC-105 不挡本地）
/// - 网络或 401 刷新后仍失败 → 异常原样上抛，**队列整条留着**（TC-SYNC-114 载荷不丢）
/// - 服务端语义：`data` 空即全部接受；有回执才逐条处置
///   - 回执带 `serverId` → 出队并回填 `remoteId`（临时 ID 映射收口）
///   - 冲突回执（客户端较旧，`RestSyncPort` 内部已按「新者胜」重推过）→ 只出队、
///     不改本地映射，接受服务端值，下次 pull 对齐
///
/// 它同时是注入给壳层的 [SyncPort]：`push()` 走真装载，`pull()` 暂直传
/// HTTP 端口（落库半边是卡 3）。
final class TaskSyncCoordinator implements SyncPort {
  TaskSyncCoordinator({
    required this._outbox,
    required this._syncPort,
  });

  final kernel.SyncOutbox _outbox;
  final RestSyncPort _syncPort;

  @override
  Future<void> push() => pushPending().then((_) {});

  @override
  Future<void> pull() => _syncPort.pull();

  /// 推送全部待发条目，返回本次出队条数。
  Future<int> pushPending() async {
    if (!await _syncPort.isSignedIn()) return 0;
    final entries = await _outbox.pending();
    if (entries.isEmpty) return 0;

    final acks = await _syncPort.pushChanges([
      for (final e in entries)
        SyncChange(
          entityType: e.entityType,
          entityId: e.entityId,
          operation: e.operation,
          payload: e.payload,
          clientMutationId: e.clientMutationId,
          clientUpdatedAt: e.clientUpdatedAt,
        ),
    ]);
    final ackByEntity = {for (final a in acks) a.entityId: a};

    for (final e in entries) {
      final ack = ackByEntity[e.entityId];
      await _outbox.acknowledge(
        entityType: e.entityType,
        entityId: e.entityId,
        serverId: (ack == null || ack.conflict != null) ? null : ack.serverId,
      );
    }
    return entries.length;
  }
}
