import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';

/// TC-SYNC-107/112 客户端半边：发件箱 → push 装载 → 回执驱动清队与回填
/// （flutter#124 卡 2；网络层用假 adapter，属契约级、未触网）。
void main() {
  late _FakeStore store;
  late _SeqAdapter adapter;
  late Dio dio;
  late _RecordingOutbox outbox;
  late RestSyncPort port;
  late TaskSyncCoordinator coordinator;

  setUp(() {
    store = _FakeStore();
    adapter = _SeqAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://lifeos.test'))
      ..httpClientAdapter = adapter;
    port = RestSyncPort(dio: dio, store: store);
    outbox = _RecordingOutbox();
    coordinator = TaskSyncCoordinator(outbox: outbox, syncPort: port);
  });

  SyncOutboxEntry entry(String id, {String operation = 'upsert'}) =>
      SyncOutboxEntry(
        entityType: 'task',
        entityId: id,
        operation: operation,
        payload: {'id': id, 'title': '买牛奶'},
        clientMutationId: 'cm-$id',
        clientUpdatedAt: 1729700000000,
      );

  test('TC-SYNC-107 离线改 3 条 → 联网：一次上送三条，键与入队时一致', () async {
    await store.write(const MemberSession(
        userId: '248', accessToken: 'tok', tenantId: '1', refreshToken: 'r'));
    outbox.seed([entry('a'), entry('b'), entry('c')]);
    adapter.enqueue({'code': 0, 'data': []});

    await coordinator.pushPending();

    final body = jsonDecode(adapter.sentBodies.single) as Map<String, dynamic>;
    final changes = body['changes'] as List;
    expect(changes, hasLength(3));
    expect(changes.map((c) => (c as Map)['entityId']), ['a', 'b', 'c']);
    expect(changes.map((c) => (c as Map)['clientMutationId']),
        ['cm-a', 'cm-b', 'cm-c'],
        reason: '上送的就是入队时生成的幂等键，不是现编的');
  });

  test('TC-SYNC-105 未登录：不发请求也不清队（本地未推送变更不丢）', () async {
    outbox.seed([entry('a')]);

    await coordinator.pushPending();

    expect(adapter.sentBodies, isEmpty);
    expect(outbox.acked, isEmpty, reason: '未登录不得把队列当「已全部接受」清空');
  });

  test('TC-SYNC-112 回执带 serverId：按实体清队并带上 serverId 回填', () async {
    await store.write(const MemberSession(
        userId: '1', accessToken: 'tok', tenantId: '1', refreshToken: 'r'));
    outbox.seed([entry('uuid-1')]);
    adapter.enqueue({
      'code': 0,
      'data': [
        {'entityId': 'uuid-1', 'serverId': 'srv-77', 'revision': 1},
      ],
    });

    await coordinator.pushPending();

    final ack = outbox.acked.single;
    expect(ack.entityType, 'task');
    expect(ack.entityId, 'uuid-1');
    expect(ack.serverId, 'srv-77', reason: 'serverId 交给发件箱写回 remoteId');
  });

  test('TC-SYNC-108 服务端「data 空即全部成功」：无回执也按接受清队', () async {
    await store.write(const MemberSession(
        userId: '1', accessToken: 'tok', tenantId: '1', refreshToken: 'r'));
    outbox.seed([entry('a'), entry('b')]);
    adapter.enqueue({'code': 0, 'data': []});

    await coordinator.pushPending();

    expect(outbox.acked.map((a) => a.entityId), ['a', 'b']);
    expect(outbox.acked.every((a) => a.serverId == null), isTrue);
  });

  test('TC-SYNC-113 冲突让位（客户端较旧）：清队但不回填', () async {
    await store.write(const MemberSession(
        userId: '1', accessToken: 'tok', tenantId: '1', refreshToken: 'r'));
    outbox.seed([entry('old')]);
    adapter.enqueue({
      'code': 0,
      'data': [
        {
          'entityId': 'old',
          // 冲突回执也带 serverId：让位路径必须**不**拿它回填
          'serverId': 'srv-conflict',
          'conflict': {
            'serverRevision': 9,
            'serverValue': {'updateTime': 99999999999999},
          },
        },
      ],
    });

    await coordinator.pushPending();

    final ack = outbox.acked.single;
    expect(ack.entityId, 'old');
    expect(ack.serverId, isNull, reason: '让位给服务端值，不能用回执里的 id 覆盖本地映射');
  });

  test('TC-SYNC-114 网络失败：队列整条留着（重登后续推）', () async {
    await store.write(const MemberSession(
        userId: '1', accessToken: 'tok', tenantId: '1', refreshToken: 'r'));
    outbox.seed([entry('a'), entry('b')]);
    adapter.enqueue401();
    adapter.enqueue401();

    await expectLater(coordinator.pushPending(), throwsA(anything));
    expect(outbox.acked, isEmpty, reason: '失败不清队——载荷不丢');
  });

  test('空队列：不发请求', () async {
    await store.write(const MemberSession(
        userId: '1', accessToken: 'tok', tenantId: '1', refreshToken: 'r'));

    expect(await coordinator.pushPending(), 0);
    expect(adapter.sentBodies, isEmpty);
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

/// 记录型发件箱：只验协调器的调用序列，落库半边在 drift 包里测。
class _RecordingOutbox implements SyncOutbox {
  final _entries = <SyncOutboxEntry>[];
  final acked = <_AckCall>[];

  void seed(List<SyncOutboxEntry> entries) => _entries
      ..clear()
      ..addAll(entries);

  @override
  Future<void> enqueue(SyncOutboxEntry entry) async => _entries.add(entry);

  @override
  Future<List<SyncOutboxEntry>> pending() async => List.of(_entries);

  @override
  Future<void> acknowledge({
    required String entityType,
    required String entityId,
    String? serverId,
  }) async {
    acked.add(_AckCall(entityType, entityId, serverId));
    _entries.removeWhere((e) => e.entityId == entityId);
  }
}

class _AckCall {
  const _AckCall(this.entityType, this.entityId, this.serverId);
  final String entityType;
  final String entityId;
  final String? serverId;
}

class _SeqAdapter implements HttpClientAdapter {
  final _queue = <dynamic>[];
  final _statuses = <int>[];
  final sentBodies = <String>[];

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
    if (requestStream != null) {
      final b = await requestStream.fold(
        BytesBuilder(),
        (BytesBuilder bb, List<int> d) => bb..add(d),
      );
      sentBodies.add(utf8.decode(b.takeBytes()));
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
