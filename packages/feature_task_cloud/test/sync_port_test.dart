import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_core/app_core.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';

/// TC-SYNC-106–108/113：同步契约（push 变更 / 幂等载荷 / 冲突「新者胜」重推）。
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

  test('TC-SYNC-107 push 变更：载荷带幂等键与 clientUpdatedAt', () async {
    adapter.enqueue({'code': 0, 'data': []});
    final sync = RestSyncPort(dio: dio, store: store);
    await store.write(const MemberSession(
      userId: '1', tenantId: '1', accessToken: 'tok',
    ));

    final acks = await sync.pushChanges([
      const SyncChange(
        entityType: 'task',
        entityId: 'uuid-local-1',
        operation: 'upsert',
        payload: {'title': '买菜'},
        clientMutationId: 'cmid-1',
        clientUpdatedAt: 1729700000000,
      ),
    ]);

    // 请求体断言：幂等键 + 时间戳上送
    final sent = jsonDecode(adapter.sentBodies.last) as Map<String, dynamic>;
    final change = (sent['changes'] as List).single as Map<String, dynamic>;
    expect(change['clientMutationId'], 'cmid-1');
    expect(change['clientUpdatedAt'], 1729700000000);
    expect(acks, isEmpty);
  });

  test('TC-SYNC-113 冲突「新者胜」：客户端较新 → 整条覆盖重推一次', () async {
    adapter.enqueue({
      'code': 0,
      'data': [
        {
          'entityId': 'uuid-local-1',
          'serverId': 'srv-9',
          'revision': 5,
          'conflict': {
            'serverRevision': 5,
            'serverValue': {'updateTime': 1729600000000},
          },
        },
      ],
    });
    // 重推回执：成功
    adapter.enqueue({'code': 0, 'data': []});
    final sync = RestSyncPort(dio: dio, store: store);
    await store.write(const MemberSession(
      userId: '1', tenantId: '1', accessToken: 'tok',
    ));

    final acks = await sync.pushChanges([
      const SyncChange(
        entityType: 'task',
        entityId: 'uuid-local-1',
        operation: 'upsert',
        payload: {'title': '新标题'},
        clientMutationId: 'cmid-2',
        clientUpdatedAt: 1729700000000, // 客户端较新
      ),
    ]);

    // 发出了两批（原推+重推）
    expect(adapter.sentBodies.length, 2);
    // 重推载荷：entityId 已换 serverId（映射回填）+ baseRevision=serverRevision
    final retry = jsonDecode(adapter.sentBodies[1]) as Map<String, dynamic>;
    final retryChange = (retry['changes'] as List).single as Map<String, dynamic>;
    expect(retryChange['entityId'], 'srv-9');
    expect(retryChange['baseRevision'], 5, reason: '重推必须带服务端基线版本');
    // 重推成功后 acks 回写：最终回执无残留冲突（cursor PR#17 阻断2）
    expect(acks.first.conflict, isNull, reason: '首轮冲突回执须被重推结果替换');
  });

  test('TC-SYNC-113 客户端较旧：接受服务端值不重推', () async {
    adapter.enqueue({
      'code': 0,
      'data': [
        {
          'entityId': 'uuid-local-1',
          'serverId': 'srv-9',
          'revision': 5,
          'conflict': {
            'serverRevision': 5,
            'serverValue': {'updateTime': 1790000000000},
          },
        },
      ],
    });
    final sync = RestSyncPort(dio: dio, store: store);
    await store.write(const MemberSession(
      userId: '1', tenantId: '1', accessToken: 'tok',
    ));

    await sync.pushChanges([
      const SyncChange(
        entityType: 'task',
        entityId: 'uuid-local-1',
        operation: 'upsert',
        clientUpdatedAt: 1729700000000, // 较旧
      ),
    ]);

    expect(adapter.sentBodies.length, 1, reason: '较旧不重推');
  });

  test('TC-SYNC-105 未登录 pushChanges 返回空且零请求', () async {
    final sync = RestSyncPort(dio: dio, store: store);
    final acks = await sync.pushChanges([
      const SyncChange(entityType: 'task', entityId: 'x', operation: 'upsert'),
    ]);
    expect(acks, isEmpty);
    expect(adapter.sentBodies, isEmpty);
  });

  test('TC-SYNC-113 连续冲突：≤maxConflictRetries 后停止（防死循环）', () async {
    // 服务端永远回冲突
    for (var i = 0; i < 6; i++) {
      adapter.enqueue({
        'code': 0,
        'data': [
          {
            'entityId': 'uuid-local-1',
            'serverId': 'srv-9',
            'revision': 5,
            'conflict': {
              'serverRevision': 5,
              'serverValue': {'updateTime': 1}, // 恒旧 → 客户端恒较新 → 恒重推
            },
          },
        ],
      });
    }
    final sync = RestSyncPort(dio: dio, store: store);
    await store.write(const MemberSession(
      userId: '1', tenantId: '1', accessToken: 'tok',
    ));

    await sync.pushChanges([
      const SyncChange(
        entityType: 'task',
        entityId: 'uuid-local-1',
        operation: 'upsert',
        clientUpdatedAt: 1729700000000,
      ),
    ]);

    expect(adapter.sentBodies.length, 1 + RestSyncPort.maxConflictRetries,
        reason: '原推 + 至多 3 次重推');
  });

  test('TC-SYNC-113 重推后 ack 回显 serverId 不炸（cursor PR#17 R2 Critical）',
      () async {
    // 第一轮回执冲突（entityId=localId）；重推后服务端回执**又冲突**且 entityId=serverId
    adapter.enqueue({
      'code': 0,
      'data': [
        {
          'entityId': 'uuid-local-1',
          'serverId': 'srv-9',
          'revision': 5,
          'conflict': {
            'serverRevision': 5,
            'serverValue': {'updateTime': 1},
          },
        },
      ],
    });
    adapter.enqueue({
      'code': 0,
      'data': [
        {
          'entityId': 'srv-9', // 服务端按上送 id 回显——旧代码会 StateError
          'serverId': 'srv-9',
          'revision': 6,
          'conflict': {
            'serverRevision': 6,
            'serverValue': {'updateTime': 1},
          },
        },
      ],
    });
    final sync = RestSyncPort(dio: dio, store: store);
    await store.write(const MemberSession(
      userId: '1', tenantId: '1', accessToken: 'tok',
    ));

    await sync.pushChanges([
      const SyncChange(
        entityType: 'task',
        entityId: 'uuid-local-1',
        operation: 'upsert',
        clientUpdatedAt: 1729700000000,
      ),
    ]);

    // 不抛 StateError（旧代码在第二轮 firstWhere 崩）；且发生了重推
    expect(adapter.sentBodies.length, greaterThanOrEqualTo(2),
        reason: 'serverId 回显被稳定键匹配，重推继续而非 StateError');
  });

  test('TC-SYNC-113 连续冲突耗尽重试：最终 acks 保留 conflict 非 null（防假成功）',
      () async {
    for (var i = 0; i < 6; i++) {
      adapter.enqueue({
        'code': 0,
        'data': [
          {
            'entityId': i == 0 ? 'uuid-local-1' : 'srv-9',
            'serverId': 'srv-9',
            'revision': 5 + i,
            'conflict': {
              'serverRevision': 5 + i,
              'serverValue': {'updateTime': 1},
            },
          },
        ],
      });
    }
    final sync = RestSyncPort(dio: dio, store: store);
    await store.write(const MemberSession(
      userId: '1', tenantId: '1', accessToken: 'tok',
    ));

    final acks = await sync.pushChanges([
      const SyncChange(
        entityType: 'task',
        entityId: 'uuid-local-1',
        operation: 'upsert',
        clientUpdatedAt: 1729700000000,
      ),
    ]);

    expect(acks.single.conflict, isNotNull,
        reason: '耗尽重试后冲突必须如实保留（假成功=数据丢失静默）');
  });

  test('TC-SYNC-113 num 类型 serverUpdateTime 正确解析', () async {
    // 服务端 JSON 数字是 num（非 int）——时间解析不得落 0 误判
    adapter.enqueue({
      'code': 0,
      'data': [
        {
          'entityId': 'e1',
          'serverId': 's1',
          'revision': 1,
          'conflict': {
            'serverRevision': 1,
            'serverValue': {'updateTime': 9999999999999},
          },
        },
      ],
    });
    final sync = RestSyncPort(dio: dio, store: store);
    await store.write(const MemberSession(
      userId: '1', tenantId: '1', accessToken: 'tok',
    ));

    final acks = await sync.pushChanges([
      const SyncChange(
        entityType: 'task',
        entityId: 'e1',
        operation: 'upsert',
        clientUpdatedAt: 1, // 远较旧
      ),
    ]);

    expect(adapter.sentBodies.length, 1, reason: 'num 解析正确→较旧→不重推');
    expect(acks.single.conflict, isNotNull, reason: '较旧保留冲突回执由 pull 对齐');
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

/// 顺序响应假 adapter：enqueue 依次出队，记录请求体。
class _SeqAdapter implements HttpClientAdapter {
  final _queue = <dynamic>[];
  final sentBodies = <String>[];

  void enqueue(dynamic response) => _queue.add(response);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      final bytes = await requestStream.fold(
        BytesBuilder(),
        (BytesBuilder b, List<int> d) => b..add(d),
      );
      sentBodies.add(utf8.decode(bytes.takeBytes()));
    }
    final body = _queue.isEmpty ? {'code': 0, 'data': []} : _queue.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}
