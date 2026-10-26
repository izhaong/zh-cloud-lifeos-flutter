// ignore_for_file: prefer_initializing_formals
import 'package:dio/dio.dart';

import 'package:app_core/app_core.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';

import 'calendar_sync_models.dart';

/// 日历同步 REST 端口（契约 §3.9；F-17）。
///
/// 登录复用 `feature_task_cloud` 的 `SessionStore`（同一 token，不建第二套）。
class RestCalendarSyncPort implements CalendarSyncPort {
  RestCalendarSyncPort({
    required Dio dio,
    required SessionStore store,
    String tenantId = '1',
  })  : _dio = dio,
        _store = store,
        _tenantId = tenantId;

  final Dio _dio;
  final SessionStore _store;
  final String _tenantId;

  Options _authed(MemberSession session) => Options(headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'tenant-id': _tenantId,
      });

  @override
  Future<CalendarPullResult?> pull({
    required String deviceId,
    String? cursor,
    int limit = 200,
  }) async {
    final session = await _store.read();
    if (session == null) {
      return null;
    }
    final resp = await _dio.post<Map<String, dynamic>>(
      '/app-api/lifeos/calendar/sync/pull',
      data: {
        'deviceId': deviceId,
        'cursor': ?cursor,
        'limit': limit,
      },
      options: _authed(session),
    );
    final data = _unwrap(resp);
    if (data == null) {
      return const CalendarPullResult(changes: [], tombstones: []);
    }
    final changes = _parseChanges(data['changes']);
    final tombstones = _parseChanges(data['tombstones']);
    return CalendarPullResult(
      changes: changes,
      tombstones: tombstones,
      nextCursor: data['nextCursor']?.toString(),
      hasMore: data['hasMore'] == true,
    );
  }

  @override
  Future<CalendarPushResult?> push({
    required String deviceId,
    required String idempotencyKey,
    required List<CalendarPushChange> changes,
  }) async {
    final session = await _store.read();
    if (session == null) {
      return null;
    }
    final resp = await _dio.post<Map<String, dynamic>>(
      '/app-api/lifeos/calendar/sync/push',
      data: {
        'deviceId': deviceId,
        'idempotencyKey': idempotencyKey,
        'changes': [for (final c in changes) c.toJson()],
      },
      options: _authed(session),
    );
    final data = _unwrap(resp);
    if (data == null) {
      return const CalendarPushResult();
    }
    return CalendarPushResult(
      ok: data['ok'] != false,
      idempotent: data['idempotent'] == true,
      accepted: [
        for (final e in (data['accepted'] as List? ?? const []))
          if (e is Map<String, dynamic>)
            CalendarAccepted(
              clientMutationId: e['clientMutationId']?.toString(),
              entityId: e['entityId']?.toString() ?? '',
              revision: (e['revision'] as num?)?.toInt(),
            ),
      ],
      conflicts: [
        for (final e in (data['conflicts'] as List? ?? const []))
          if (e is Map<String, dynamic>)
            CalendarConflict(
              clientMutationId: e['clientMutationId']?.toString(),
              reason: e['reason']?.toString(),
              serverValue: _asMap(e['serverValue']),
              clientValue: _asMap(e['clientValue']),
            ),
      ],
      nextCursor: data['nextCursor']?.toString(),
    );
  }

  Map<String, dynamic>? _unwrap(Response<Map<String, dynamic>> resp) {
    final body = resp.data;
    if (body == null || body['code'] != 0) {
      throw CalendarSyncException(
        body?['msg']?.toString() ?? '同步失败',
        statusCode: resp.statusCode,
      );
    }
    final data = body['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  List<CalendarPullChange> _parseChanges(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>)
          CalendarPullChange(
            entityType: e['entityType']?.toString() ?? '',
            entityId: e['entityId']?.toString() ?? '',
            operation: e['operation']?.toString() ?? 'UPSERT',
            revision: (e['revision'] as num?)?.toInt(),
            payload: _asMap(e['payload']),
          ),
    ];
  }

  static Map<String, dynamic> _asMap(dynamic value) =>
      value is Map<String, dynamic> ? value : const {};
}
