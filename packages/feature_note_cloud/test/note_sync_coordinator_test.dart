// TC-NOTE-SYNC-101（#415）：记录域同步协调器。
//
// 三条硬约束：未登录零请求 / 先推后拉 / **落库成功才前进游标**（失败不能丢变更）。
import 'package:feature_note_cloud/feature_note_cloud.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;
import 'package:flutter_test/flutter_test.dart';

class _FakeHttp implements NoteSyncHttp {
  final List<Map<String, dynamic>> posts = [];
  Map<String, dynamic> pullResponse = const {'data': {'changes': []}};

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    posts.add({'path': path, 'body': body});
    if (path == RestSyncPort.pullPath) {
      return pullResponse;
    }
    return const {'data': {}};
  }
}

class _FakeOutbox implements kernel.SyncOutbox {
  final List<kernel.SyncOutboxEntry> entries = [];
  final List<String> acked = [];

  @override
  Future<void> enqueue(kernel.SyncOutboxEntry entry) async => entries.add(entry);

  @override
  Future<List<kernel.SyncOutboxEntry>> pending() async =>
      List.unmodifiable(entries);

  @override
  Future<void> acknowledge({
    required String entityType,
    required String entityId,
    String? serverId,
  }) async {
    entries.removeWhere(
        (e) => e.entityType == entityType && e.entityId == entityId);
    acked.add('$entityType:$entityId');
  }
}

class _FakeApplier implements kernel.SyncApplier {
  final List<kernel.SyncIncomingChange> applied = [];
  Object? failWith;

  @override
  Future<void> applyAll(Iterable<kernel.SyncIncomingChange> changes) async {
    if (failWith != null) throw failWith!;
    applied.addAll(changes);
  }
}

class _FakeCursors implements kernel.SyncCursorStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String cursor) async => value = cursor;
}

void main() {
  late _FakeHttp http;
  late _FakeOutbox outbox;
  late _FakeApplier applier;
  late _FakeCursors cursors;
  late NoteSyncCoordinator coordinator;

  setUp(() {
    http = _FakeHttp();
    outbox = _FakeOutbox();
    applier = _FakeApplier();
    cursors = _FakeCursors();
    coordinator = NoteSyncCoordinator(
      outbox: outbox,
      applier: applier,
      cursors: cursors,
      port: RestSyncPort(http: http),
    );
  });

  test('TC-NOTE-SYNC-101 未登录 → 零请求、零出队', () async {
    outbox.entries.add(const kernel.SyncOutboxEntry(
      entityType: 'note',
      entityId: 'n1',
      operation: 'upsert',
      payload: {'id': 'n1'},
      clientMutationId: 'm1',
      clientUpdatedAt: 1,
    ));

    final report = await coordinator.syncOnce();

    expect(report.skipped, isTrue);
    expect(http.posts, isEmpty);
    expect(outbox.entries, hasLength(1), reason: '未登录不能把队列清空');
  });

  test('TC-NOTE-SYNC-101 先推后拉：推送成功才出队', () async {
    coordinator = NoteSyncCoordinator(
      outbox: outbox,
      applier: applier,
      cursors: cursors,
      port: RestSyncPort(http: http)..session = const NoteSyncSession(token: 't', userId: '1'),
    );
    outbox.entries.add(const kernel.SyncOutboxEntry(
      entityType: 'note',
      entityId: 'n1',
      operation: 'upsert',
      payload: {'id': 'n1', 'title': 'x'},
      clientMutationId: 'm1',
      clientUpdatedAt: 1,
    ));
    http.pullResponse = const {
      'data': {
        'changes': [
          {
            'entityType': 'note',
            'entityId': 'n2',
            'operation': 'upsert',
            'data': {'id': 'n2', 'title': '来自服务端'},
          },
        ],
        'nextCursor': 'c1',
      },
    };

    final report = await coordinator.syncOnce();

    expect(report.pushed, 1);
    expect(outbox.acked, contains('note:n1'));
    expect(outbox.entries, isEmpty);
    // 先 push 后 pull
    expect(http.posts.first['path'], RestSyncPort.pushPath);
    expect(http.posts.last['path'], RestSyncPort.pullPath);
    expect(applier.applied.single.entityId, 'n2');
    expect(cursors.value, 'c1');
    expect(report.pulled, 1);
  });

  test('TC-NOTE-SYNC-101 落库失败 → 游标不前进（不丢变更）', () async {
    coordinator = NoteSyncCoordinator(
      outbox: outbox,
      applier: applier,
      cursors: cursors,
      port: RestSyncPort(http: http)..session = const NoteSyncSession(token: 't', userId: '1'),
    );
    http.pullResponse = const {
      'data': {
        'changes': [
          {'entityType': 'note', 'entityId': 'n3', 'operation': 'upsert', 'data': {'id': 'n3'}},
        ],
        'nextCursor': 'c9',
      },
    };
    applier.failWith = StateError('落库炸了');

    await expectLater(coordinator.syncOnce(), throwsA(isA<StateError>()));
    expect(cursors.value, isNull, reason: '落库失败时游标必须留在原位，下次重拉');
  });

  test('TC-NOTE-SYNC-101 空页也前进游标（否则永远重复拉同一页）', () async {
    coordinator = NoteSyncCoordinator(
      outbox: outbox,
      applier: applier,
      cursors: cursors,
      port: RestSyncPort(http: http)..session = const NoteSyncSession(token: 't', userId: '1'),
    );
    http.pullResponse = const {
      'data': {'changes': [], 'nextCursor': 'c2'},
    };

    await coordinator.syncOnce();

    expect(cursors.value, 'c2');
    expect(applier.applied, isEmpty);
  });

  test('TC-NOTE-SYNC-101 文件夹变更也走 applier（entityType=folder）', () async {
    coordinator = NoteSyncCoordinator(
      outbox: outbox,
      applier: applier,
      cursors: cursors,
      port: RestSyncPort(http: http)..session = const NoteSyncSession(token: 't', userId: '1'),
    );
    http.pullResponse = const {
      'data': {
        'changes': [
          {'entityType': 'folder', 'entityId': 'f1', 'operation': 'upsert', 'data': {'name': '工作'}},
        ],
      },
    };

    await coordinator.syncOnce();

    expect(applier.applied.single.entityType, 'folder');
  });
}
