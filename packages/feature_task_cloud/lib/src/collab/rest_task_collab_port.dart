// ignore_for_file: prefer_initializing_formals
import 'package:dio/dio.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../auth/secure_session_store.dart';

/// `/app-api/lifeos/task/**` 的清单共享端口（flutter#570）。
///
/// 契约来自 zh-cloud-service #587（写侧六端点）与 #589（手机号解析 + 我参与的清单）。
/// 与 `RestCalendarCollabPort` 同形：Dio + [SessionStore]，业务信封 `code != 0` 一律抛
/// [TaskCollabException]——不把「未登录」「非成员」折成空列表，否则 UI 会把失败读成空。
class RestTaskCollabPort implements TaskCollabPort {
  RestTaskCollabPort({
    required Dio dio,
    required SessionStore store,
    String tenantId = '1',
  }) : _dio = dio,
       _store = store,
       _tenantId = tenantId;

  final Dio _dio;
  final SessionStore _store;
  final String _tenantId;

  Future<Options> _options() async {
    final session = await _store.read();
    if (session == null) {
      throw TaskCollabException('未登录');
    }
    return Options(
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'tenant-id': _tenantId,
      },
    );
  }

  static String _serverId(String id) {
    final parsed = int.tryParse(id);
    if (parsed == null) {
      throw TaskCollabException('这份清单还没有服务端编号（未同步过）');
    }
    return '$parsed';
  }

  @override
  Future<String?> whoAmI() async => (await _store.read())?.userId;

  @override
  Future<List<TaskListMember>> listMembers(String listId) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/app-api/lifeos/task/list/${_serverId(listId)}/members',
      options: await _options(),
    );
    return [
      for (final e in _asList(_unwrapData(resp.data)))
        TaskListMember(
          memberUserId: '${e['memberUserId']}',
          role: '${e['role']}',
          status: '${e['status']}',
          nickname: e['memberNickname']?.toString(),
        ),
    ];
  }

  @override
  Future<String> resolveUserByMobile(String mobile) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/app-api/lifeos/task/list-member/resolve',
      queryParameters: {'mobile': mobile.trim()},
      options: await _options(),
    );
    final data = _unwrapData(resp.data);
    final userId = data?['userId'];
    if (userId == null) {
      throw TaskCollabException('该手机号没有注册用户');
    }
    return '$userId';
  }

  @override
  Future<void> inviteMembers(
    String listId, {
    required List<String> userIds,
    required String role,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/app-api/lifeos/task/list/${_serverId(listId)}/members',
      data: {
        'memberUserIds': [for (final id in userIds) int.parse(id)],
        'role': role,
      },
      options: await _options(),
    );
  }

  @override
  Future<void> updateMemberRole(
    String listId,
    String userId,
    String role,
  ) async {
    await _dio.patch<Map<String, dynamic>>(
      '/app-api/lifeos/task/list/${_serverId(listId)}/members/${_serverId(userId)}',
      data: {'role': role},
      options: await _options(),
    );
  }

  @override
  Future<void> removeMember(String listId, String userId) async {
    await _dio.delete<Map<String, dynamic>>(
      '/app-api/lifeos/task/list/${_serverId(listId)}/members/${_serverId(userId)}',
      options: await _options(),
    );
  }

  @override
  Future<void> joinList(String listId) async {
    await _dio.post<Map<String, dynamic>>(
      '/app-api/lifeos/task/list/${_serverId(listId)}/member/join',
      options: await _options(),
    );
  }

  @override
  Future<void> exitList(String listId) async {
    await _dio.post<Map<String, dynamic>>(
      '/app-api/lifeos/task/list/${_serverId(listId)}/member/exit',
      options: await _options(),
    );
  }

  @override
  Future<List<TaskSharedList>> mySharedLists() async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/app-api/lifeos/task/list-member/my-lists',
      options: await _options(),
    );
    return [
      for (final e in _asList(_unwrapData(resp.data)))
        TaskSharedList(
          listId: '${e['listId']}',
          name: '${e['name'] ?? ''}',
          ownerUserId: '${e['ownerUserId']}',
          role: '${e['role']}',
        ),
    ];
  }

  /// 共享清单条目：`/lifeos/task/task/page`（`AppLifeosTaskItemController.getTaskPage`）。
  ///
  /// 走的是**读侧**通道，服务端按 active 成员放行；这里不写本地表、不进 outbox。
  /// `dueAt` 兼容两种序列化：芋道默认把 `LocalDateTime` 写成 epoch 毫秒，
  /// 但 OpenAPI/测试桩里也见过 ISO 字符串，两种都要能落。
  @override
  Future<List<TaskSharedItem>> sharedListTasks(
    String listId, {
    bool includeCompleted = false,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/app-api/lifeos/task/task/page',
      queryParameters: {
        'listId': _serverId(listId),
        'includeCompleted': includeCompleted,
        'pageNo': 1,
        'pageSize': 100,
      },
      options: await _options(),
    );
    final page = _unwrapData(resp.data);
    return [
      for (final e in _asList(page is Map ? page['list'] : null))
        TaskSharedItem(
          id: '${e['id']}',
          listId: '${e['listId']}',
          title: '${e['title'] ?? ''}',
          notes: e['notes']?.toString(),
          dueAt: _date(e['dueAt']),
          allDay: e['allDay'] == true,
          priority: (e['priority'] as num?)?.toInt() ?? 0,
          flagged: e['isFlagged'] == true,
          completed: e['isCompleted'] == true,
          tagNames: [
            for (final t in (e['tagNames'] as List? ?? const [])) '$t',
          ],
        ),
    ];
  }

  static DateTime? _date(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    return DateTime.tryParse('$raw');
  }

  /// 业务信封：`code == 0` 才取 data；否则把服务端的中文 `msg` 原样抛出。
  dynamic _unwrapData(Map<String, dynamic>? body) {
    if (body == null) {
      throw TaskCollabException('请求失败');
    }
    if (body['code'] != 0) {
      throw TaskCollabException('${body['msg'] ?? '请求失败'}');
    }
    return body['data'];
  }

  List<Map<String, dynamic>> _asList(dynamic raw) => [
    for (final e in (raw as List? ?? const []))
      if (e is Map<String, dynamic>) e,
  ];
}
