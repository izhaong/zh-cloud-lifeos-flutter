// FL #595：「上次同步」时间戳只在**一轮成功**后盖；未登录不去查发件箱。
import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/task_sync_wiring.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _FakeOutbox implements SyncOutbox {
  _FakeOutbox(this.entries);
  final List<SyncOutboxEntry> entries;
  int pendingCalls = 0;

  @override
  Future<List<SyncOutboxEntry>> pending() async {
    pendingCalls++;
    return entries;
  }

  @override
  Future<void> enqueue(SyncOutboxEntry entry) async {}

  @override
  Future<void> acknowledge({
    required String entityType,
    required String entityId,
    String? serverId,
  }) async {}
}

final class _FakeAuth implements AuthPort {
  _FakeAuth(this.session);
  final MemberSession? session;

  @override
  Future<MemberSession?> currentSession() async => session;

  @override
  Future<MemberSession> login({
    required String username,
    required String password,
  }) async =>
      session!;

  @override
  Future<void> logout() async {}

  @override
  Future<MemberSession?> refresh() async => null;
}

void main() {
  final stamp = DateTime(2026, 11, 3, 9, 41);

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const {});
  });

  TaskSyncRound round({
    required SharedPreferences prefs,
    Future<void> Function()? pull,
    Future<void> Function()? syncOnce,
  }) =>
      TaskSyncRound(
        onPush: () async {},
        onPull: pull ?? (() async {}),
        onSyncOnce: syncOnce ?? (() async {}),
        prefs: prefs,
        clock: () => stamp,
      );

  test('回前台一轮成功 → 盖「上次同步」时间戳', () async {
    final prefs = await SharedPreferences.getInstance();
    await round(prefs: prefs).pull();
    expect(prefs.getInt(taskLastSyncKey), stamp.millisecondsSinceEpoch);
  });

  test('冷启动 syncOnce 成功 → 同样盖时间戳', () async {
    final prefs = await SharedPreferences.getInstance();
    await round(prefs: prefs, syncOnce: () async {}).runOnce();
    expect(prefs.getInt(taskLastSyncKey), stamp.millisecondsSinceEpoch);
  });

  test('pull 抛错（弱网超时）→ 不盖戳，旧值保留', () async {
    final prefs = await SharedPreferences.getInstance();
    final earlier = DateTime(2026, 11, 2, 8, 5);
    await prefs.setInt(taskLastSyncKey, earlier.millisecondsSinceEpoch);

    Future<void> boom() async => throw StateError('SocketException（受控注入）');
    await expectLater(round(prefs: prefs, pull: boom).pull(), throwsStateError);
    expect(prefs.getInt(taskLastSyncKey), earlier.millisecondsSinceEpoch,
        reason: '失败的一轮不算「上次同步」');
  });

  test('单独 push 不盖戳（这一轮还没走完）', () async {
    final prefs = await SharedPreferences.getInstance();
    await round(prefs: prefs).push();
    expect(prefs.getInt(taskLastSyncKey), isNull);
  });

  test('已登录：状态 = 待发条数 + 上次成功同步时刻', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(taskLastSyncKey, stamp.millisecondsSinceEpoch);
    final outbox = _FakeOutbox(const [
      SyncOutboxEntry(
        entityType: 'task',
        entityId: 'a',
        operation: 'upsert',
        payload: {},
        clientMutationId: 'm1',
        clientUpdatedAt: 1,
      ),
      SyncOutboxEntry(
        entityType: 'task',
        entityId: 'b',
        operation: 'delete',
        payload: {},
        clientMutationId: 'm2',
        clientUpdatedAt: 2,
      ),
    ]);
    final status = await readTaskSyncStatus(
      auth: _FakeAuth(
        const MemberSession(userId: '309', tenantId: '1', accessToken: 't'),
      ),
      outbox: outbox,
      prefs: prefs,
    );
    expect(status.loggedIn, isTrue);
    expect(status.pendingCount, 2);
    expect(status.lastSyncAt, DateTime.fromMillisecondsSinceEpoch(
        stamp.millisecondsSinceEpoch));
    expect(status.settingsLabel, '待推 2 条 · 上次同步 09:41');
  });

  test('未登录：不查发件箱，也不摆状态文案', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(taskLastSyncKey, stamp.millisecondsSinceEpoch);
    final outbox = _FakeOutbox(const []);
    final status = await readTaskSyncStatus(
      auth: _FakeAuth(null),
      outbox: outbox,
      prefs: prefs,
    );
    expect(outbox.pendingCalls, 0, reason: '未登录不该为状态文案去读库');
    expect(status.settingsLabel, isNull);
  });
}
