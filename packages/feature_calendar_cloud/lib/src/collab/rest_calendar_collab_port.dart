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

  /// TC-CAL-API-104：互斥置默认日历（服务端 `PUT /calendar/set-default?id=`）。
  Future<void> setDefaultCalendar(int calendarId);

  /// TC-CAL-API-140：导出单日历 .ics，返回服务端 `text/calendar` 原文。
  Future<String> exportCalendarIcs(int calendarId);

  /// TC-CAL-API-143：导出全部本地日历为一个 .ics。
  Future<String> exportAllIcs();

  /// TC-CAL-API-115：复制日程，服务端返回新日程编号。
  Future<int> duplicateEvent(int eventId, {required DateTime newStartAt});
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

  @override
  Future<void> setDefaultCalendar(int calendarId) async {
    await _dio.put<Map<String, dynamic>>(
      '/app-api/lifeos/calendar/calendar/set-default',
      queryParameters: {'id': calendarId},
      options: await _options(),
    );
  }

  @override
  Future<String> exportCalendarIcs(int calendarId) =>
      _getPlain('/app-api/lifeos/calendar/export/calendar/$calendarId.ics');

  @override
  Future<String> exportAllIcs() =>
      _getPlain('/app-api/lifeos/calendar/export/all.ics');

  @override
  Future<int> duplicateEvent(int eventId, {required DateTime newStartAt}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/app-api/lifeos/calendar/event/duplicate',
      queryParameters: {
        'id': eventId,
        'newStartAt': newStartAt.toUtc().toIso8601String(),
      },
      options: await _options(),
    );
    final body = resp.data;
    if (body == null || body['code'] != 0) {
      throw CalendarSyncException(body?['msg']?.toString() ?? '请求失败');
    }
    return (body['data'] as num).toInt();
  }

  /// .ics 端点返回 `text/calendar` 而非 CommonResult 信封，只能按纯文本取。
  /// 非 VCALENDAR 正文（网关错误页等）一律不外传，避免把整页 HTML 甩给 UI。
  Future<String> _getPlain(String path) async {
    final resp = await _dio.get<String>(
      path,
      options: (await _options()).copyWith(responseType: ResponseType.plain),
    );
    final body = resp.data ?? '';
    if (!body.contains('BEGIN:VCALENDAR')) {
      throw CalendarSyncException('导出失败', statusCode: resp.statusCode);
    }
    return body;
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
