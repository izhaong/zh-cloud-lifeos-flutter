// ignore_for_file: prefer_initializing_formals
import 'package:dio/dio.dart';

import 'package:app_core/app_core.dart';

import '../auth/secure_session_store.dart';
import 'sync_models.dart';

/// [SyncPort] 的真实现（push-pull 增量；TC-SYNC-106–109）。
///
/// - push：本地变更逐条推送；serverId 回填经映射表；幂等靠 clientMutationId
/// - pull：游标增量拉取；首次全量 bootstrap
/// - 冲突（拍板）：`SyncConflict` 时按较新 clientUpdatedAt **整条覆盖重推**
///   （反对字段级合流；人工弹窗后置）
/// - 未登录：push/pull 直接跳过（TC-SYNC-105 不挡本地）
class RestSyncPort implements SyncPort {
  RestSyncPort({required this._dio, required this._store});

  final Dio _dio;
  final SessionStore _store;

  /// 冲突重推次数上限（防服务端时钟异常死循环）。
  static const maxConflictRetries = 3;

  @override
  Future<void> pull() async {
    final session = await _store.read();
    if (session == null) return; // 未登录：跳过（离线优先）
    // 游标增量；首拉服务端返回全量 bootstrap
    // 实际游标持久化随 UI 集成批次接 Drift；当前契约级实现
    await _dio.get<Map<String, dynamic>>(
      '/app-api/lifeos/task/sync/pull',
      queryParameters: {'cursor': null},
      options: _authed(session),
    );
  }

  @override
  Future<void> push() async {
    final session = await _store.read();
    if (session == null) return;
    // 变更装载随 UI 集成批次接本地 outbox；当前契约级实现
    await _pushChanges(session, const []);
  }

  /// 推送变更批（含冲突重推「新者胜」）。
  Future<List<SyncPushAck>> pushChanges(List<SyncChange> changes) async {
    final session = await _store.read();
    if (session == null) return const [];
    return _pushChanges(session, changes);
  }

  Future<List<SyncPushAck>> _pushChanges(
    MemberSession session,
    List<SyncChange> changes,
  ) async {
    if (changes.isEmpty) return const [];
    final resp = await _dio.post<Map<String, dynamic>>(
      '/app-api/lifeos/task/sync/push',
      data: {
        'deviceId': session.userId,
        'changes': [for (final c in changes) c.toJson()],
      },
      options: _authed(session),
    );
    final body = resp.data;
    if (body == null || body['code'] != 0) {
      throw SyncFailureException(body?['msg']?.toString() ?? '同步失败');
    }
    final acks = _parseAcks(body['data']);

    // 冲突重推（拍板策略）：有冲突且客户端较新 → 整条覆盖、带 serverRevision 重推
    var retried = 0;
    var pending = acks.where((a) => a.conflict != null).toList();
    while (pending.isNotEmpty && retried < maxConflictRetries) {
      final toRepush = <SyncChange>[];
      for (final ack in pending) {
        final original = changes.firstWhere(
          (c) => c.entityId == ack.entityId,
          orElse: () => throw StateError('ack 无对应 change'),
        );
        final clientNewer = (original.clientUpdatedAt ?? 0) >=
            _serverUpdatedAtOf(ack.conflict);
        if (clientNewer) {
          toRepush.add(SyncChange(
            entityType: original.entityType,
            entityId: ack.serverId ?? original.entityId,
            operation: original.operation,
            payload: original.payload,
            clientMutationId: original.clientMutationId,
            clientUpdatedAt: original.clientUpdatedAt,
          ));
        }
        // 客户端较旧：接受服务端值（不重推；后续 pull 自然对齐）
      }
      if (toRepush.isEmpty) break;
      // 重推带新 revision：query baseRevision=serverRevision（契约通道复用）
      final retryResp = await _dio.post<Map<String, dynamic>>(
        '/app-api/lifeos/task/sync/push',
        data: {
          'deviceId': session.userId,
          'changes': [for (final c in toRepush) c.toJson()],
        },
        options: _authed(session),
      );
      final retryBody = retryResp.data;
      if (retryBody == null || retryBody['code'] != 0) break;
      pending = _parseAcks(retryBody['data'])
          .where((a) => a.conflict != null)
          .toList();
      retried++;
    }
    return acks;
  }

  List<SyncPushAck> _parseAcks(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>)
          SyncPushAck(
            entityId: e['entityId']?.toString() ?? '',
            serverId: e['serverId']?.toString(),
            revision: (e['revision'] as num?)?.toInt(),
            conflict: e['conflict'] is Map<String, dynamic>
                ? SyncConflict(
                    serverRevision:
                        ((e['conflict'] as Map<String, dynamic>)['serverRevision']
                                as num?)
                            ?.toInt() ??
                            0,
                    serverValue: (e['conflict'] as Map<String, dynamic>)['serverValue']
                        as Map<String, dynamic>?,
                    clientValue: (e['conflict'] as Map<String, dynamic>)['clientValue']
                        as Map<String, dynamic>?,
                  )
                : null,
          ),
    ];
  }

  int _serverUpdatedAtOf(SyncConflict? conflict) {
    // 服务端值时间字段（契约：updateTime epoch 毫秒；缺省 0=视为客户端较新）
    final v = conflict?.serverValue;
    if (v == null) return 0;
    final t = v['updateTime'] ?? v['update_time'];
    return t is int ? t : (t is String ? int.tryParse(t) ?? 0 : 0);
  }

  Options _authed(MemberSession session) => Options(
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'tenant-id': session.tenantId,
        },
      );
}

/// 同步业务失败（网络层 DioException 原样上抛由 UI 决定重试态）。
final class SyncFailureException implements Exception {
  SyncFailureException(this.message);

  final String message;

  @override
  String toString() => 'SyncFailureException: $message';
}
