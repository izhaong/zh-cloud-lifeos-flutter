// 私有字段 + 公共命名参数：构造函数赋值形式比 `this._xxx` 的可读性更好，故关闭该 lint。
// ignore_for_file: prefer_initializing_formals

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;

import 'note_sync_models.dart';
import 'rest_sync_port.dart';

/// 一轮同步的结果（供组合根/测试断言）。
class NoteSyncReport {
  const NoteSyncReport({
    this.pushed = 0,
    this.rejected = 0,
    this.pulled = 0,
    this.skipped = false,
    this.shouldStop = false,
  });

  /// 本次**出队**（服务端明确受理）的条数。
  final int pushed;

  /// 服务端未受理、**留在队列**的条数（#428：不能再当成已推送）。
  final int rejected;

  /// 本次落库的入站变更条数。
  final int pulled;

  /// 未登录 → 零请求直接返回。
  final bool skipped;

  /// pull 返回 `hasMore`：调用方可以再跑一轮把剩余页拉完。
  final bool shouldStop;
}

/// 记录域同步协调器（#415 / 契约 §6）。
///
/// 编排顺序**先推后拉**（与任务侧一致）：本地变更先让服务端按 baseRevision 裁决，
/// 再把裁决结果拉回来——反过来会把对端较新的值当成本地待推变更覆盖掉。
///
/// 三条硬约束：
/// 1. **未登录零请求**：`RestSyncPort.push/pull` 内部已按 session 短路，这里再提前返回一次
///    （省掉读发件箱/游标的开销，也让测试能断言「零请求」）；
/// 2. **落库成功后才前进游标**：applier 抛异常时游标不动，下次从原位续拉（不丢变更）；
/// 3. **入站不回写发件箱**：由 applier 保证（#414）。
class NoteSyncCoordinator {
  NoteSyncCoordinator({
    required kernel.SyncOutbox outbox,
    required kernel.SyncApplier applier,
    required kernel.SyncCursorStore cursors,
    required RestSyncPort port,
  })  : _outbox = outbox,
        _applier = applier,
        _cursors = cursors,
        _port = port;

  final kernel.SyncOutbox _outbox;
  final kernel.SyncApplier _applier;
  final kernel.SyncCursorStore _cursors;
  final RestSyncPort _port;

  /// 一轮完整同步：先推本地待发，再拉增量并落库。
  Future<NoteSyncReport> syncOnce() async {
    if (_port.session == null) {
      return const NoteSyncReport(skipped: true);
    }
    final push = await _pushPending();
    final pull = await _pullAndApply();
    return NoteSyncReport(
      pushed: push.acked,
      rejected: push.rejected,
      pulled: pull.applied,
      shouldStop: !pull.hasMore,
    );
  }

  /// 推送发件箱里的待发条目，返回出队条数。
  ///
  /// 服务端语义：`RestSyncPort.push` 内部已按冲突重试（最多 3 次，同一幂等键）；
  /// 它正常返回即视为本批**已被接受**，逐条出队。
  Future<({int acked, int rejected})> _pushPending() async {
    final pending = await _outbox.pending();
    if (pending.isEmpty) {
      return (acked: 0, rejected: 0);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final changes = <NoteSyncChange>[
      for (final entry in pending)
        NoteSyncChange(
          entityType: entry.entityType == 'folder'
              ? NoteSyncEntityType.folder
              : NoteSyncEntityType.note,
          payload: entry.payload,
          operation: entry.operation.toUpperCase(),
        ),
    ];
    final result = await _port.push(
      changes,
      clientMutationId: 'note-batch-$now',
      clientUpdatedAt: now,
    );
    // #428：只对**服务端明确受理**的条目出队。此前无脑全出队，部分拒绝时
    // 那条变更就永久丢了（`NotePushResult` 当时只有 attempts/conflicts）。
    var acked = 0;
    var rejected = 0;
    for (final entry in pending) {
      if (!result.isAcknowledged(entry.entityId)) {
        rejected++;
        continue; // 留在队列，下轮重推（宁可重复推，不可丢）
      }
      await _outbox.acknowledge(
        entityType: entry.entityType,
        entityId: entry.entityId,
      );
      acked++;
    }
    return (acked: acked, rejected: rejected);
  }

  /// 拉增量 → 落库 →（成功后）前进游标。
  Future<({int applied, bool hasMore})> _pullAndApply() async {
    final cursor = await _cursors.read();
    final result = await _port.pullChanges(cursor: cursor);
    if (result.changes.isEmpty) {
      if (result.nextCursor != null && result.nextCursor != cursor) {
        await _cursors.write(result.nextCursor!);
      }
      return (applied: 0, hasMore: result.hasMore);
    }
    // 顺序关键：先落库，成功后才写游标。
    await _applier.applyAll(result.changes);
    final next = result.nextCursor;
    if (next != null && next != cursor) {
      await _cursors.write(next);
    }
    return (applied: result.changes.length, hasMore: result.hasMore);
  }
}

/// 与任务侧 `RestSyncPort` 重名时的显式别名（#416）：组合根同时 import 两个 cloud 包，
/// 用别名比在 import 上写 `hide/show` 更好读。
typedef NoteRestSyncPort = RestSyncPort;
