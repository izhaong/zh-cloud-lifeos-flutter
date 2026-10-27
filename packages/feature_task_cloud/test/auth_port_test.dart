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
    // 静态 mock 状态必须每条清一次，否则上一条的 queue 会漏到下一条
    _JsonAdapter.nextResponse = null;
    _JsonAdapter.queue = const [];
    _JsonAdapter.callCount = 0;
    _JsonAdapter.lastPath = null;
    _JsonAdapter.lastQuery = const {};
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

  // ---------------- TC-SYNC-114 refresh 通道 ----------------

  /// 登录 resp 带 refreshToken ⇒ 会话与 store 都要存住（不然下一次刷新无从下手）。
  test('TC-SYNC-114 登录：refreshToken 一并入会话与存储', () async {
    _JsonAdapter.nextResponse = {
      'code': 0,
      'data': {
        'userId': 7,
        'accessToken': 'acc-1',
        'refreshToken': 'ref-1',
      },
    };
    final auth = RestAuthPort(dio: dio, store: store);

    final session = await auth.login(username: 'x', password: 'y');

    expect(session.refreshToken, 'ref-1');
    final stored = await store.read();
    expect(stored?.refreshToken, 'ref-1', reason: '会话不写穿 store ⇒ 重启就再也刷不了');
  });

  test('TC-SYNC-114 refresh 成功：写回新会话并返回它', () async {
    _JsonAdapter.queue = [
      {'code': 0, 'data': {'userId': 1, 'accessToken': 'acc-old', 'refreshToken': 'ref-old'}},
      {'code': 0, 'data': {'userId': 1, 'accessToken': 'acc-new', 'refreshToken': 'ref-new'}},
    ];
    final auth = RestAuthPort(dio: dio, store: store);
    await auth.login(username: 'u', password: 'p');

    final next = await auth.refresh();

    expect(next?.accessToken, 'acc-new');
    expect(next?.refreshToken, 'ref-new');
    final stored = await store.read();
    expect(stored?.accessToken, 'acc-new', reason: 'refresh 后必须换 store 里的旧 token');
    // 刷新端点要求带 refreshToken 作 query 参数（不是 header/body）
    expect(_JsonAdapter.lastPath, '/app-api/member/auth/refresh-token');
    expect(_JsonAdapter.lastQuery['refreshToken'], 'ref-old');
  });

  test('TC-SYNC-114 refresh 无 refreshToken：直接返回 null 且不发请求', () async {
    _JsonAdapter.queue = [
      {'code': 0, 'data': {'userId': 1, 'accessToken': 'only'}},
    ];
    final auth = RestAuthPort(dio: dio, store: store);
    await auth.login(username: 'u', password: 'p');
    final callsBefore = _JsonAdapter.callCount;

    final next = await auth.refresh();

    expect(next, isNull);
    expect(_JsonAdapter.callCount, callsBefore,
        reason: '没 refreshToken 还发请求 = 拿脏参数撞 400 上抛，属未做输入校验');
  });

  test('TC-SYNC-114 refresh 失败：清会话返回 null，下次同步走未登录旁路', () async {
    _JsonAdapter.queue = [
      {'code': 0, 'data': {'userId': 1, 'accessToken': 'acc', 'refreshToken': 'ref'}},
      {'code': 401, 'msg': 'refreshToken 过期'},
    ];
    final auth = RestAuthPort(dio: dio, store: store);
    await auth.login(username: 'u', password: 'p');

    final next = await auth.refresh();

    expect(next, isNull);
    expect(await store.read(), isNull,
        reason: 'refresh 不成就清会话；留着过期 token 只会被 pull/push 反复 401');
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
  /// 单条 mock（旧用例走这条）。
  static dynamic nextResponse;

  /// 队列 mock（TC-SYNC-114 用例需要 login → refresh 两次不同响应）；非空时优先。
  static List<dynamic> queue = const [];
  static int callCount = 0;
  static String? lastPath;
  static Map<String, dynamic> lastQuery = const {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    lastPath = options.path;
    lastQuery = Map<String, dynamic>.from(options.queryParameters);
    dynamic body;
    if (queue.isNotEmpty) {
      body = queue.first;
      queue = queue.sublist(1);
    } else {
      body = nextResponse;
      nextResponse = null;
    }
    return ResponseBody.fromString(
      body == null ? '{}' : jsonEncode(body),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}
