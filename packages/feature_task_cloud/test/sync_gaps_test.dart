import 'dart:convert';
import 'dart:typed_data';

import 'package:app_core/app_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_task_cloud/feature_task_cloud.dart';

/// TC-SYNC-106/108/112/114（T-05）：pull 解析 / 幂等键不换 /
/// serverId→remoteId 回填 / 401 静默重试一次（本地变更不丢）。
void main() {
  late _FakeStore store;
  late _SeqAdapter adapter;
  late Dio dio;

  setUp(() {
    store = _FakeStore();
    adapter = _SeqAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://lifeos.test'))
      ..httpClientAdapter = adapter;
  });

  RestSyncPort port() => RestSyncPort(dio: dio, store: store);

  MemberSession session() => const MemberSession(
        userId: '1',
        tenantId: '1',
        accessToken: 'tok',
      );

  test('TC-SYNC-106 pull：服务端回一条任务变更，解析为 SyncChange 结果流', () async {
    await store.write(session());
    adapter.enqueue({
      'code': 0,
      'data': {
        'nextCursor': 'c-2',
        'changes': [
          {
            'changeId': 101,
            'entityType': 'task',
            'entityId': 'srv-9',
            'operation': 'upsert',
            'revision': 3,
            'payload': {'title': '买牛奶'},
          },
        ],
      },
    });

    final result = await port().pullChanges();

    expect(result.cursor, 'c-2');
    expect(result.changes, hasLength(1));
    final c = result.changes.single;
    expect(c.entityType, 'task');
    expect(c.entityId, 'srv-9');
    expect(c.operation, 'upsert');
    expect(c.baseRevision, 3, reason: '服务端下推 revision 即客户端基线版本');
    expect(c.payload['title'], '买牛奶');
  });

  /// TC-SYNC-107 客户端半边：契约 §3.9 两端都是 POST（`AppLifeosTaskSyncController`），
  /// 客户端此前 pull 用 GET 且把游标塞进 query——本用例把方法、body 形态与游标字段名钉死，
  /// 免得再漂回 GET/`cursor`（服务端 `PullRespVO` 用 `nextCursor`，读错就是永远拉从头）。
  test('TC-SYNC-107 pull 走 POST：body 带 deviceId/cursor，游标读 nextCursor', () async {
    await store.write(session());
    adapter.enqueue({
      'code': 0,
      'data': {'nextCursor': 'c-9', 'changes': <Object>[]},
    });

    final result = await port().pullChanges(cursor: 'c-8');

    expect(result.cursor, 'c-9');
    expect(adapter.lastMethod, 'POST', reason: '契约 §3.9：两端都是 POST');
    final body = jsonDecode(adapter.lastBody!) as Map<String, dynamic>;
    expect(body['deviceId'], '1', reason: '游标按 deviceId 隔离，不带上就是每次从头');
    expect(body['cursor'], 'c-8');
    expect(
      body.containsKey('queryParameters'),
      isFalse,
      reason: '参数不再走 query（GET 时代遗留），全部塞 body',
    );
  });

  test('TC-SYNC-108 幂等键不换：同 clientMutationId 连推两次，第二次请求体同键',
      () async {
    await store.write(session());
    adapter.enqueue({'code': 0, 'data': []});
    adapter.enqueue({'code': 0, 'data': []});

    const change = SyncChange(
      entityType: 'task',
      entityId: 'uuid-1',
      operation: 'upsert',
      clientMutationId: 'cmid-stable',
      clientUpdatedAt: 1729700000000,
    );
    await port().pushChanges([change]);
    await port().pushChanges([change]);

    final req1 = jsonDecode(adapter.sentBodies[0]) as Map<String, dynamic>;
    final req2 = jsonDecode(adapter.sentBodies[1]) as Map<String, dynamic>;
    expect(
      (req1['changes'] as List).single['clientMutationId'],
      'cmid-stable',
    );
    expect(
      (req2['changes'] as List).single['clientMutationId'],
      'cmid-stable',
      reason: '断网重试不得换幂等键（服务端按键去重）',
    );
  });

  test('TC-SYNC-112 serverId 回填：push 回执映射能产出 remoteId', () async {
    await store.write(session());
    adapter.enqueue({
      'code': 0,
      'data': [
        {'entityId': 'uuid-1', 'serverId': 'srv-77', 'revision': 1},
      ],
    });

    final acks = await port().pushChanges([
      const SyncChange(
        entityType: 'task',
        entityId: 'uuid-1',
        operation: 'upsert',
        clientMutationId: 'cmid-1',
      ),
    ]);

    expect(acks.single.serverId, 'srv-77', reason: 'serverId 即本地 remoteId 来源');
  });

  test('TC-SYNC-114 401 静默重试：一次 401 后重试原请求成功', () async {
    await store.write(session());
    // 第一次响应 401；第二次 200
    adapter.enqueue401();
    adapter.enqueue({'code': 0, 'data': []});

    final acks = await port().pushChanges([
      const SyncChange(
        entityType: 'task',
        entityId: 'e1',
        operation: 'upsert',
        clientMutationId: 'cmid-r',
      ),
    ]);

    expect(adapter.sentBodies, hasLength(2), reason: '401 后静默重试一次');
    expect(acks, isEmpty, reason: '重试成功——无冲突回执');
  });

  test('TC-SYNC-114 重试仍失败：上抛异常但已推载荷不丢（本地队列语义）', () async {
    await store.write(session());
    adapter.enqueue401();
    adapter.enqueue401();

    await expectLater(
      port().pushChanges([
        const SyncChange(
          entityType: 'task',
          entityId: 'e2',
          operation: 'upsert',
          clientMutationId: 'cmid-r2',
        ),
      ]),
      throwsA(anything),
    );
    expect(adapter.sentBodies, hasLength(2), reason: '试满两次');
  });

  /// TC-SYNC-114 正题：401 后必须走 **refresh 换 token 再重发**，
  /// 而不是拿同一张过期 token 空转重试。断言不是「重发过几次」而是
  /// 「第二次请求的 Authorization 头是**新** token」——只数次数会把
  /// 老实现（同 token 重发）也判成绿。
  test('TC-SYNC-114 401 走 refresh 通道：重发用的是新 token', () async {
    await store.write(session());
    adapter.enqueue401();
    adapter.enqueue({'code': 0, 'data': []});
    var refreshCalled = 0;
    final port = RestSyncPort(
      dio: dio,
      store: store,
      refreshSession: () async {
        refreshCalled++;
        // 模拟 RestAuthPort.refresh()：写新会话进 store，返回 true 让上层重发
        await store.write(const MemberSession(
          userId: '1',
          tenantId: '1',
          accessToken: 'tok-new',
        ));
        return true;
      },
    );

    await port.pushChanges([
      const SyncChange(
        entityType: 'task',
        entityId: 'e-refresh',
        operation: 'upsert',
        clientMutationId: 'cmid-rf',
      ),
    ]);

    expect(refreshCalled, 1, reason: '401 时 refresh 恰好调一次（不许循环刷）');
    expect(adapter.sentAuth, hasLength(2));
    expect(adapter.sentAuth[0], 'Bearer tok', reason: '第一次仍是旧 token');
    expect(adapter.sentAuth[1], 'Bearer tok-new',
        reason: '重发必须读 store 里的**新**会话；同 token 重发=本用例要防的老路径');
  });

  /// 反向：refresh 返回 false（无 refreshToken / 换 token 失败清会话）⇒
  /// 退回同 token 重试一次的老行为，向后兼容不炸既有 TC-SYNC-114 用例。
  test('TC-SYNC-114 refresh 不 ok：走老路（同 token 重发一次）', () async {
    await store.write(session());
    adapter.enqueue401();
    adapter.enqueue({'code': 0, 'data': []});
    var refreshCalled = 0;
    final port = RestSyncPort(
      dio: dio,
      store: store,
      refreshSession: () async {
        refreshCalled++;
        return false;
      },
    );

    await port.pushChanges([
      const SyncChange(
        entityType: 'task',
        entityId: 'e-nofresh',
        operation: 'upsert',
        clientMutationId: 'cmid-nf',
      ),
    ]);

    expect(refreshCalled, 1);
    expect(adapter.sentAuth, hasLength(2));
    expect(adapter.sentAuth[0], 'Bearer tok');
    expect(adapter.sentAuth[1], 'Bearer tok',
        reason: 'refresh 不 ok 就沿用老 token——不引入新逻辑，只多一个可插钩子');
  });
}

class _FakeStore implements SessionStore {
  MemberSession? _session;

  @override
  Future<MemberSession?> read() async => _session;

  @override
  Future<void> write(MemberSession s) async => _session = s;

  @override
  Future<void> clear() async => _session = null;
}

class _SeqAdapter implements HttpClientAdapter {
  final _queue = <dynamic>[];
  final _statuses = <int>[];
  final sentBodies = <String>[];

  /// 最近一次请求的 method 与 body——TC-SYNC-107 用它钉住 pull 走 POST 与 body 形态。
  String lastMethod = '';
  String? lastBody;

  /// TC-SYNC-114：每次请求的 Authorization 头（含 Bearer 前缀，原样存），
  /// 用它断「401 后重发用的是**新** token」而不是"重发过一次"。
  final sentAuth = <String?>[];

  void enqueue(dynamic response) {
    _queue.add(response);
    _statuses.add(200);
  }

  void enqueue401() {
    _queue.add({'code': 401, 'msg': '未登录或令牌过期'});
    _statuses.add(401);
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastMethod = options.method;
    lastBody = null;
    sentAuth.add(options.headers['Authorization']?.toString());
    if (requestStream != null) {
      final b = await requestStream.fold(
        BytesBuilder(),
        (BytesBuilder bb, List<int> d) => bb..add(d),
      );
      final decoded = utf8.decode(b.takeBytes());
      sentBodies.add(decoded);
      lastBody = decoded;
    }
    final status = _statuses.isEmpty ? 200 : _statuses.removeAt(0);
    final body = _queue.isEmpty ? {'code': 0, 'data': []} : _queue.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}
