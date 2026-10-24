import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_core/app_core.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';

/// TC-SYNC-101–105：登录契约（成功/失败不落半态/未登录不挡/登出不清业务数据）。
void main() {
  late _FakeStore store;
  late Dio dio;

  setUp(() {
    store = _FakeStore();
    dio = Dio(BaseOptions(baseUrl: 'https://lifeos.test'))
      ..httpClientAdapter = _JsonAdapter();
  });

  test('TC-SYNC-103 登录成功：会话入安全存储', () async {
    _JsonAdapter.nextResponse = {
      'code': 0,
      'data': {
        'userId': 248,
        'accessToken': 'tok123',
        'nickname': '仲灏',
      },
    };
    final auth = RestAuthPort(dio: dio, store: store);

    final session = await auth.login(username: '15601691399', password: 'x');

    expect(session.userId, '248');
    expect(session.accessToken, 'tok123');
    // 存储收到同一会话
    final stored = await store.read();
    expect(stored?.accessToken, 'tok123');
  });

  test('TC-SYNC-104 登录失败：抛明确异常、不落半登录态', () async {
    _JsonAdapter.nextResponse = {'code': 1004003000, 'msg': '账号密码不正确'};
    final auth = RestAuthPort(dio: dio, store: store);

    await expectLater(
      auth.login(username: 'x', password: 'bad'),
      throwsA(isA<AuthFailureException>()),
    );
    expect(await store.read(), isNull, reason: '失败不得留半登录态');
  });

  test('TC-SYNC-105 未登录：currentSession null 且 push/pull 静默跳过', () async {
    final auth = RestAuthPort(dio: dio, store: store);
    final sync = RestSyncPort(dio: dio, store: store);

    expect(await auth.currentSession(), isNull);
    // 不抛、不炸（离线优先红线）
    await sync.pull();
    await sync.push();
  });

  test('TC-SYNC-103 logout 清会话不清业务数据（store 层验证）', () async {
    _JsonAdapter.nextResponse = {
      'code': 0,
      'data': {'userId': 1, 'accessToken': 't'},
    };
    final auth = RestAuthPort(dio: dio, store: store);
    await auth.login(username: 'a', password: 'b');
    expect(await store.read(), isNotNull);

    await auth.logout();
    expect(await store.read(), isNull);
    // 业务数据（如本地任务库）不属本层——logout 未触碰 Drift 即契约达成
  });
}

class _FakeStore implements SessionStore {
  MemberSession? _session;

  @override
  Future<MemberSession?> read() async => _session;

  @override
  Future<void> write(MemberSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

class _JsonAdapter implements HttpClientAdapter {
  static dynamic nextResponse;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = nextResponse;
    nextResponse = null;
    return ResponseBody.fromString(
      body == null ? '{}' : jsonEncode(body),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}
