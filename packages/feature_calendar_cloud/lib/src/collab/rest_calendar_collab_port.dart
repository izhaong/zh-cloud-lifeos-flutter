// ignore_for_file: prefer_initializing_formals
import 'package:dio/dio.dart';

import 'package:feature_task_cloud/feature_task_cloud.dart';

import '../sync/calendar_sync_models.dart';

/// 收件箱 / 共享 / 导入导出（契约 §3.3–§3.6；F-17 UI 用）。
abstract interface class CalendarCollabPort {
  Future<List<Map<String, dynamic>>> inboxList();

  Future<void> respondShare(int shareId, {required bool accept});

  Future<List<Map<String, dynamic>>> calendarList();

  Future<String?> exportFeedUrl(int? calendarId);

  Future<void> importIcs({
    required int calendarId,
    required String filename,
    required List<int> bytes,
  });
}

class RestCalendarCollabPort implements CalendarCollabPort {
  RestCalendarCollabPort({
    required Dio dio,
    required SessionStore store,
    String tenantId = '1',
  })  : _dio = dio,
        _store = store,
        _tenantId = tenantId;

  final Dio _dio;
  final SessionStore _store;
  final String _tenantId;

  Future<Options> _options() async {
    final session = await _store.read();
    if (session == null) {
      throw CalendarSyncException('未登录', statusCode: 401);
    }
    return Options(headers: {
      'Authorization': 'Bearer ${session.accessToken}',
      'tenant-id': _tenantId,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> inboxList() async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/app-api/lifeos/calendar/inbox/list',
      queryParameters: {'state': 'ALL', 'pageNo': 1, 'pageSize': 50},
      options: await _options(),
    );
    final data = _unwrap(resp.data);
    final list = data?['list'] ?? data?['records'];
    return _asList(list);
  }

  @override
  Future<void> respondShare(int shareId, {required bool accept}) async {
    await _dio.post<Map<String, dynamic>>(
      '/app-api/lifeos/calendar/calendar/share/respond',
      data: {'shareId': shareId, 'accept': accept},
      options: await _options(),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> calendarList() async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/app-api/lifeos/calendar/calendar/list',
      options: await _options(),
    );
    return _asList(_unwrap(resp.data));
  }

  @override
  Future<String?> exportFeedUrl(int? calendarId) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/app-api/lifeos/calendar/export/feed-url',
      queryParameters: {'calendarId': ?calendarId},
      options: await _options(),
    );
    final data = _unwrap(resp.data);
    return data?['url']?.toString();
  }

  @override
  Future<void> importIcs({
    required int calendarId,
    required String filename,
    required List<int> bytes,
  }) async {
    final form = FormData.fromMap({
      'targetCalendarId': calendarId,
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await _dio.post<Map<String, dynamic>>(
      '/app-api/lifeos/calendar/import/ics',
      data: form,
      options: await _options(),
    );
  }

  Map<String, dynamic>? _unwrap(Map<String, dynamic>? body) {
    if (body == null || body['code'] != 0) {
      throw CalendarSyncException(body?['msg']?.toString() ?? '请求失败');
    }
    final data = body['data'];
    return data is Map<String, dynamic>
        ? data
        : (data is List ? {'list': data} : null);
  }

  List<Map<String, dynamic>> _asList(dynamic raw) => [
        for (final e in (raw as List? ?? const []))
          ?e,
      ];
}
