// 私有字段 + 公共命名参数的取舍：构造赋值比 `this._dio` 好读。
// ignore_for_file: prefer_initializing_formals

// 记录域同步的组合根接线（#416）。
//
// `feature_note_cloud` 刻意不依赖 dio / 会话存储（开源包不打网络）：它只声明
// `NoteSyncHttp` 端口。真正的 HTTP 适配与会话桥接放在壳里——和日历/任务一致。
import 'package:dio/dio.dart';
import 'package:feature_note_cloud/feature_note_cloud.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart'
    show SessionStore;

/// `NoteSyncHttp` 的 Dio 实现：带登录 token 与 tenant-id，401 交由调用方上抛。
class DioNoteSyncHttp implements NoteSyncHttp {
  DioNoteSyncHttp({
    required Dio dio,
    required SessionStore store,
    this.tenantId = '1',
  })  : _dio = dio,
        _store = store;

  final Dio _dio;
  final SessionStore _store;
  final String tenantId;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final session = await _store.read();
    final resp = await _dio.post<Map<String, dynamic>>(
      path,
      data: body,
      options: Options(headers: {
        if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        'tenant-id': tenantId,
      }),
    );
    return resp.data ?? const <String, dynamic>{};
  }
}

/// 跑一轮记录同步；未登录零请求、失败不挡本地（与日历/任务同一口径）。
///
/// 会话每次都从 [SessionStore] 现读并写到端口上——登录/登出不需要重建协调器。
Future<void> syncNotesOnce({
  required NoteSyncCoordinator coordinator,
  required RestSyncPort port,
  required SessionStore store,
  required DateTime Function() clock,
}) async {
  final session = await store.read();
  port.session = session == null
      ? null
      : NoteSyncSession(
          token: session.accessToken,
          userId: session.userId.toString(),
        );
  if (port.session == null) {
    return; // 未登录：零请求
  }
  await coordinator.syncOnce();
}
