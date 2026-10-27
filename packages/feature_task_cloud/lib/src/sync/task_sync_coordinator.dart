import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;

import 'rest_sync_port.dart';
import 'sync_models.dart';

/// 任务域同步协调器（flutter#124 卡 2 + 卡 3 / TC-SYNC-106、107、108、109、112）。
///
/// push 半边：仓库层把本地变更写进发件箱，这里一次成批上送并按回执出队——
/// - 未登录 / 队空 → 直接返回，不发请求、不动队列（TC-SYNC-105 不挡本地）
/// - 网络或 401 刷新后仍失败 → 异常原样上抛，**队列整条留着**（TC-SYNC-114 载荷不丢）
/// - 服务端语义：`data` 空即全部接受；有回执才逐条处置
///   - 回执带 `serverId` → 出队并回填 `remoteId`（临时 ID 映射收口）
///   - 冲突回执（客户端较旧，`RestSyncPort` 内部已按「新者胜」重推过）→ 只出队、
///     不改本地映射，接受服务端值
///
/// pull 半边（卡 3）：带上次游标拉增量 → 交落库侧写 Drift（delete 进回收窗）→
/// **落库成功后**才前进游标。
///
/// 顺序取「先推后拉」：本地变更先让服务端按 baseRevision 裁决，再把裁决结果拉回来，
/// 避免把对端较新的值当作本地待推变更覆盖掉。
///
/// 它同时是注入给壳层的 [SyncPort]。
final class TaskSyncCoordinator implements SyncPort {
  TaskSyncCoordinator({
    required this._outbox,
    required this._syncPort,
    required this._applier,
    required this._cursors,
  });

  final kernel.SyncOutbox _outbox;
  final RestSyncPort _syncPort;
  final kernel.SyncApplier _applier;
  final kernel.SyncCursorStore _cursors;

  @override
  Future<void> push() => pushPending().then((_) {});

  @override
  Future<void> pull() => pullAndApply().then((_) {});

  /// 一轮完整同步：先推本地，再拉增量落库。
  Future<void> syncOnce() async {
    await pushPending();
    await pullAndApply();
  }

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

  /// 带上次游标拉增量 → 落库 → 落库成功后才前进游标。
  ///
  /// 顺序不能反：游标先走等于把这批变更判了死刑（下次不再下发，本地永远缺）。
  Future<PullResult> pullAndApply() async {
    if (!await _syncPort.isSignedIn()) {
      return const PullResult(cursor: null, changes: []);
    }
    final result = await _syncPort.pullChanges(cursor: await _cursors.read());
    await _applier.applyAll([
      for (final c in result.changes)
        kernel.SyncIncomingChange(
          entityType: c.entityType,
          entityId: c.entityId,
          operation: c.operation,
          payload: c.payload,
        ),
    ]);
    final next = result.cursor;
    if (next != null) await _cursors.write(next);
    return result;
  }
}
