// TC-NOTE-SYNC-101 组合根（#416）：记录域同步必须真的接上，且未登录零请求。
//
// 这条测试盯的是**接线**而不是组件：#413/#414/#415 三段都在，但 `git grep
// feature_note_cloud -- main.dart` 曾经是 0 命中——「零件齐了、没人组装」。
import 'package:app_core/app_core.dart';
import 'package:dio/dio.dart';
import 'package:feature_note_cloud/feature_note_cloud.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    show SyncApplier, SyncCursorStore, SyncIncomingChange, SyncOutbox, SyncOutboxEntry;
import 'package:feature_task_cloud/feature_task_cloud.dart' show SessionStore;
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/note_sync_wiring.dart';

class _FakeStore implements SessionStore {
  MemberSession? session;

  @override
  Future<MemberSession?> read() async => session;

  @override
  Future<void> write(MemberSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

class _FakeHttp implements NoteSyncHttp {
  final List<String> paths = [];
  Map<String, dynamic> response = const {'data': {'changes': []}};

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    paths.add(path);
    return response;
  }
}

class _NoopOutbox implements SyncOutbox {
  @override
  Future<void> enqueue(SyncOutboxEntry entry) async {}
  @override
  Future<List<SyncOutboxEntry>> pending() async => const [];
  @override
  Future<void> acknowledge({
    required String entityType,
    required String entityId,
    String? serverId,
  }) async {}
}

class _NoopApplier implements SyncApplier {
  @override
  Future<void> applyAll(Iterable<SyncIncomingChange> changes) async {}
}

class _NoopCursors implements SyncCursorStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String cursor) async => value = cursor;
}

void main() {
  test('#416 未登录：syncNotesOnce 零请求', () async {
    final http = _FakeHttp();
    final store = _FakeStore();
    final port = NoteRestSyncPort(http: http);

    await syncNotesOnce(
      coordinator: NoteSyncCoordinator(
        outbox: _NoopOutbox(),
        applier: _NoopApplier(),
        cursors: _NoopCursors(),
        port: port,
      ),
      port: port,
      store: store,
      clock: () => DateTime(2026, 10, 29),
    );

    expect(http.paths, isEmpty);
    expect(port.session, isNull);
  });

  test('#416 已登录：跑一轮（先 push 后 pull），会话从 store 现读', () async {
    final http = _FakeHttp();
    final store = _FakeStore()
      ..session = const MemberSession(
        accessToken: 'token-abc',
        userId: '7',
        tenantId: '1',
      );
    final port = NoteRestSyncPort(http: http);
    final cursors = _NoopCursors();

    await syncNotesOnce(
      coordinator: NoteSyncCoordinator(
        outbox: _NoopOutbox(),
        applier: _NoopApplier(),
        cursors: cursors,
        port: port,
      ),
      port: port,
      store: store,
      clock: () => DateTime(2026, 10, 29),
    );

    expect(port.session, isNotNull);
    expect(port.session!.token, 'token-abc');
    expect(http.paths, [NoteRestSyncPort.pullPath],
        reason: '发件箱为空时只有 pull 一次（push 无待发条目）');
  });

  test('#416 DioNoteSyncHttp 带 Authorization 与 tenant-id', () async {
    final store = _FakeStore()
      ..session = const MemberSession(accessToken: 'tk', userId: '9', tenantId: '1');
    final captured = <Map<String, dynamic>>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      captured.add({
        'path': options.path,
        'headers': Map<String, dynamic>.from(options.headers),
      });
      handler.resolve(Response<Map<String, dynamic>>(
        requestOptions: options,
        data: const {'data': {}},
      ));
    }));

    final http = DioNoteSyncHttp(dio: dio, store: store);
    await http.post(NoteRestSyncPort.pushPath, const {'domain': 'note'});

    expect(captured.single['path'], NoteRestSyncPort.pushPath);
    final headers = captured.single['headers'] as Map<String, dynamic>;
    expect(headers['Authorization'], 'Bearer tk');
    expect(headers['tenant-id'], '1');
  });
}
