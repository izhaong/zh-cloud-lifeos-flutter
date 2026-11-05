import 'dart:convert';

import 'package:app_core/app_core.dart';
import 'package:dio/dio.dart';
import 'package:feature_calendar_cloud/feature_calendar_cloud.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

/// #604：四个「服务端早有、客户端此前无调用面」的端点，逐条核请求形状。
/// 这里的锚点是 develop 上现读的 Java 签名：
/// `AppLifeosCalendarController.java:72`（set-default）、
/// `AppLifeosCalendarIcsController.java:54/60`（两个 .ics 导出）、
/// `AppLifeosCalendarEventController.java:92`（event/duplicate）。
void main() {
  final store = _Store();
  late _RecAdapter adapter;
  late RestCalendarCollabPort port;

  setUp(() {
    adapter = _RecAdapter();
    port = RestCalendarCollabPort(
      dio: Dio()..httpClientAdapter = adapter,
      store: store,
    );
  });

  test('TC-CAL-API-104 setDefaultCalendar 走 PUT /calendar/set-default?id=',
      () async {
    adapter.json = {'code': 0, 'data': true};
    await port.setDefaultCalendar(7);
    expect(adapter.lastMethod, 'PUT');
    expect(adapter.lastPath, '/app-api/lifeos/calendar/calendar/set-default');
    expect(adapter.lastQuery['id'], 7);
  });

  test('TC-CAL-API-140 exportCalendarIcs 按 id 拼路径并回传纯文本正文', () async {
    adapter.plain = 'BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR';
    final ics = await port.exportCalendarIcs(7);
    expect(adapter.lastMethod, 'GET');
    expect(adapter.lastPath, '/app-api/lifeos/calendar/export/calendar/7.ics');
    expect(ics, startsWith('BEGIN:VCALENDAR'));
  });

  test('TC-CAL-API-143 exportAllIcs 走 /export/all.ics', () async {
    adapter.plain = 'BEGIN:VCALENDAR\nEND:VCALENDAR';
    expect(await port.exportAllIcs(), contains('END:VCALENDAR'));
    expect(adapter.lastPath, '/app-api/lifeos/calendar/export/all.ics');
  });

  test('#165 同源约束：导出拿到非 VCALENDAR 正文（网关错误页）时抛错且不回显正文',
      () async {
    adapter.plain = '<html><body>502 Bad Gateway</body></html>';
    await expectLater(
      port.exportAllIcs(),
      throwsA(isA<CalendarSyncException>()
          .having((e) => e.message, 'message', '导出失败')),
    );
  });

  test('TC-CAL-API-115 duplicateEvent 传 id 与 UTC newStartAt，返回新编号',
      () async {
    adapter.json = {'code': 0, 'data': 99};
    final newId = await port.duplicateEvent(5,
        newStartAt: DateTime.utc(2026, 11, 4, 3, 30));
    expect(adapter.lastMethod, 'POST');
    expect(adapter.lastPath, '/app-api/lifeos/calendar/event/duplicate');
    expect(adapter.lastQuery['id'], 5);
    expect(adapter.lastQuery['newStartAt'], '2026-11-04T03:30:00.000Z');
    expect(newId, 99);
  });

  test('未登录：四个端点都不发请求，直接 401 语义抛错', () async {
    store.session = null;
    expect(adapter.requests, 0);
    await expectLater(
        port.setDefaultCalendar(1), throwsA(isA<CalendarSyncException>()));
    await expectLater(
        port.exportCalendarIcs(1), throwsA(isA<CalendarSyncException>()));
    await expectLater(
        port.exportAllIcs(), throwsA(isA<CalendarSyncException>()));
    await expectLater(
      port.duplicateEvent(1, newStartAt: DateTime.utc(2026)),
      throwsA(isA<CalendarSyncException>()),
    );
    expect(adapter.requests, 0, reason: '未登录不该打网络');
  });

  test('CommonResult 信封 code 非 0 时抛错（复制日程的业务失败）', () async {
    adapter.json = {'code': 1_070_105_001, 'msg': '没有该日历的访问权限'};
    await expectLater(
      port.duplicateEvent(5, newStartAt: DateTime.utc(2026)),
      throwsA(isA<CalendarSyncException>()),
    );
  });
}

class _Store implements SessionStore {
  MemberSession? session = const MemberSession(
      userId: '1', tenantId: '1', accessToken: 'token');

  @override
  Future<MemberSession?> read() async => session;

  @override
  Future<void> write(MemberSession s) async => session = s;

  @override
  Future<void> clear() async => session = null;
}

class _RecAdapter implements HttpClientAdapter {
  Map<String, dynamic>? json;
  String? plain;
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic> lastQuery = {};
  int requests = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<dynamic>? cancelFuture) async {
    requests++;
    lastMethod = options.method;
    lastPath = options.path;
    lastQuery = options.queryParameters;
    final text = plain;
    if (text != null) {
      return ResponseBody.fromString(
        text,
        200,
        headers: {
          Headers.contentTypeHeader: ['text/calendar;charset=UTF-8'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(json ?? {'code': 0, 'data': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
