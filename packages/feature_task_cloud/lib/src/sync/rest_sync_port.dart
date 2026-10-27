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
  RestSyncPort({
    required this._dio,
    required this._store,
    Future<bool> Function()? refreshSession,
  }) : _refreshSession = refreshSession;

  final Dio _dio;
  final SessionStore _store;

  /// TC-SYNC-114：401 时先走这条换 token（返回 true=刷新成功，可重试）。
  /// 组合根注入 `RestAuthPort::refresh`；未注入（如离线单测）时 401 走老路径重试一次同 token，
  /// 保持向后兼容不炸旧用例。
  final Future<bool> Function()? _refreshSession;

  /// 冲突重推次数上限（防服务端时钟异常死循环）。
  static const maxConflictRetries = 3;

  /// 用当前 store 里的会话（refresh 之后已换新 token）；未登录返回 null。
  Future<MemberSession?> _currentSession() => _store.read();

  /// 401 分支共用：先尝试 refresh，成功返回 true 让上层重发（重发时读**新**会话即可拿到新 token）。
  Future<bool> _tryRefresh() async {
    final hook = _refreshSession;
    if (hook == null) return false;
    return await hook();
  }

  /// 是否已有会话。发件箱装载器用它决定要不要动队列：
  /// 未登录时 `pushChanges` 返回空回执，装载器若按「空=全部接受」清队就把本地变更抹了。
  Future<bool> isSignedIn() async => await _store.read() != null;

  @override
  Future<void> pull() async {
    await pullChanges();
  }

  /// 增量拉取（T-05 TC-SYNC-106/107）：返回游标+变更批；未登录空结果。
  ///
  /// **契约 §3.9 两端都是 POST**（`AppLifeosTaskSyncController`），body 需带 `deviceId`
  /// 与 `cursor`——游标按设备隔离，不带 `deviceId` 就等于每次从头。响应字段是 `nextCursor`，
  /// 不是 `cursor`（服务端 `PullRespVO.setNextCursor`）；读错字段名会「永远拉同一批」但
  /// 不抛异常，是最难查的一种漂移。
  Future<PullResult> pullChanges({String? cursor}) async {
    final session = await _store.read();
    if (session == null) {
      return const PullResult(cursor: null, changes: []);
    }
    final resp = await _dio.post<Map<String, dynamic>>(
      '/app-api/lifeos/task/sync/pull',
      data: {'deviceId': session.userId, 'cursor': cursor},
      options: _authed(session),
    );
    final body = resp.data;
    if (body == null || body['code'] != 0) {
      throw SyncFailureException(body?['msg']?.toString() ?? '拉取失败');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      return const PullResult(cursor: null, changes: []);
    }
    return PullResult(
      cursor: data['nextCursor']?.toString(),
      changes: _parsePullChanges(data['changes']),
    );
  }

  List<SyncChange> _parsePullChanges(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>)
          SyncChange(
            entityType: e['entityType']?.toString() ?? '',
            entityId: e['entityId']?.toString() ?? '',
            operation: e['operation']?.toString() ?? 'upsert',
            payload: (e['payload'] is Map<String, dynamic>)
                ? e['payload'] as Map<String, dynamic>
                : const {},
            clientMutationId: e['clientMutationId']?.toString(),
            baseRevision: (e['revision'] as num?)?.toInt(),
          ),
    ];
  }

  @override
  Future<void> push() async {
    // 卡 2 后真装载归 TaskSyncCoordinator.pushPending()（它才是注入壳层的 SyncPort）：
    // 本类看不见 Drift 发件箱（包依赖方向），直接调本方法即「不带载荷」而非假装推过。
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
    final body = await _postPushWithRetry(session, changes);
    var acks = _parseAcks(body?['data']);

    // 冲突重推（拍板策略）：客户端较新 → 整条覆盖、带 baseRevision=serverRevision。
    // 稳定键=originalId（首轮 localId）：重推 change 的 entityId 可能已换 serverId，
    // ack↔change 匹配一律经 originalId 映射（cursor PR#17 R2：服务端回显 serverId
    // 时旧 firstWhere 会 StateError；连续冲突回写需按原键）。
    var retried = 0;
    var pending = acks.where((a) => a.conflict != null).toList();
    // originalId → 本轮重推前的最新已知 id（首轮=localId；后续轮=serverId）
    final currentIdByOriginal = <String, String>{
      for (final c in changes) c.entityId: c.entityId,
    };
    final baseByOriginal = <String, int>{};
    while (pending.isNotEmpty && retried < maxConflictRetries) {
      final toRepush = <SyncChange>[];
      final repushOriginals = <String>[];
      for (final ack in pending) {
        // ack.entityId 可能是 localId（首轮）或 serverId（重推轮回显）
        final originalId = _resolveOriginalId(ack, currentIdByOriginal);
        final original = changes.firstWhere(
          (c) => c.entityId == originalId,
          orElse: () => throw StateError('ack 无对应 change'),
        );
        final clientNewer = (original.clientUpdatedAt ?? 0) >=
            _serverUpdatedAtOf(ack.conflict);
        if (clientNewer) {
          final upsertId = ack.serverId ??
              currentIdByOriginal[originalId] ??
              original.entityId;
          baseByOriginal[originalId] = ack.conflict!.serverRevision;
          currentIdByOriginal[originalId] = upsertId;
          repushOriginals.add(originalId);
          toRepush.add(SyncChange(
            entityType: original.entityType,
            entityId: upsertId,
            operation: original.operation,
            payload: original.payload,
            clientMutationId: original.clientMutationId,
            clientUpdatedAt: original.clientUpdatedAt,
            baseRevision: ack.conflict!.serverRevision,
          ));
        }
        // 客户端较旧：接受服务端值（不重推；后续 pull 自然对齐）
      }
      if (toRepush.isEmpty) break;
      final retryBody = await _postPushWithRetry(session, toRepush);
      if (retryBody == null || retryBody['code'] != 0) break;
      final retryAcks = _parseAcks(retryBody['data']);
      // 回写（稳定键=originalId）：服务端语义=「data 空即全部成功；
      // 有冲突才逐条回执（ack.entityId=本轮上送 id=serverId）」。
      // serverId→originalId 反查后匹配：重推又冲突→替换为新回执；
      // 无回执→清空 conflict（成功）。
      final idToOriginal = <String, String>{};
      currentIdByOriginal.forEach((orig, cur) => idToOriginal[cur] = orig);
      final retryConflictByOriginal = <String, SyncPushAck>{};
      for (final a in retryAcks) {
        if (a.conflict != null) {
          final orig = idToOriginal[a.entityId] ?? a.entityId;
          // 归一化回执到 originalId 键域：后续轮回写才能稳定匹配
          // （回写替换后 acks 元素须保持 entityId=originalId，否则下轮
          // retryConflictByOriginal 按 originalId 查不到 → 误判成功）
          retryConflictByOriginal[orig] = SyncPushAck(
            entityId: orig,
            serverId: a.serverId,
            revision: a.revision,
            conflict: a.conflict,
          );
        }
      }
      acks = [
        for (final a in acks)
          if (a.conflict != null)
            (retryConflictByOriginal.containsKey(a.entityId))
                ? retryConflictByOriginal[a.entityId]!
                // 仅本轮**实际重推**的条目可清空（repushOriginals）；
                // 混合批中较旧未重推的冲突回执须保留（cursor PR#17 R3：防假成功变体）
                : (repushOriginals.contains(a.entityId))
                    ? SyncPushAck(
                        entityId: a.entityId,
                        serverId: a.serverId,
                        revision: a.revision,
                      )
                    : a
          else
            a,
      ];
      pending = retryAcks.where((a) => a.conflict != null).toList();
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

  /// ack.entityId（localId 或 serverId）→ 原 change 的 localId。
  String _resolveOriginalId(
    SyncPushAck ack,
    Map<String, String> currentIdByOriginal,
  ) {
    if (currentIdByOriginal.containsKey(ack.entityId)) return ack.entityId;
    for (final e in currentIdByOriginal.entries) {
      if (e.value == ack.entityId) return e.key;
    }
    return ack.entityId;
  }

  int _serverUpdatedAtOf(SyncConflict? conflict) {
    // 服务端值时间字段（契约：updateTime epoch 毫秒；缺省 0=视为客户端较新）
    final v = conflict?.serverValue;
    if (v == null) return 0;
    final t = v['updateTime'] ?? v['update_time'];
    if (t is num) return t.toInt();
    if (t is String) return int.tryParse(t) ?? 0;
    return 0;
  }

  /// TC-SYNC-114：401 → 先走 refreshSession 回调换 accessToken，再拿**新会话**重发一次；
  /// 没注入回调（离线单测/未接 AuthPort）时退回"同 token 再发一次"的老路径，保持向后兼容。
  /// 载荷不清空（无论刷新成功与否都保留原 changes 与幂等键）——下次同步还会带上。
  Future<Map<String, dynamic>?> _postPushWithRetry(
    MemberSession session,
    List<SyncChange> changes,
  ) async {
    Future<Response<Map<String, dynamic>?>> sendWith(MemberSession s) =>
        _dio.post<Map<String, dynamic>>(
          '/app-api/lifeos/task/sync/push',
          data: {
            'deviceId': s.userId,
            'changes': [for (final c in changes) c.toJson()],
          },
          options: _authed(s),
        );
    try {
      final resp = await sendWith(session);
      final body = resp.data;
      if (body == null || body['code'] != 0) {
        throw SyncFailureException(body?['msg']?.toString() ?? '同步失败');
      }
      return body;
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) rethrow;
      final refreshed = await _tryRefresh();
      final retrySession = refreshed ? (await _currentSession() ?? session) : session;
      final resp = await sendWith(retrySession);
      final body = resp.data;
      if (body == null || body['code'] != 0) {
        throw SyncFailureException(body?['msg']?.toString() ?? '同步失败');
      }
      return body;
    }
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
