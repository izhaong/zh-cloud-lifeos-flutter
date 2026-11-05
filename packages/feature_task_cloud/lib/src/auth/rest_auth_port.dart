// ignore_for_file: prefer_initializing_formals
import 'package:dio/dio.dart';

import 'package:app_core/app_core.dart';

import 'secure_session_store.dart';

/// [AuthPort] 的 member 真实现（TC-SYNC-101–105）。
///
/// - 登录走 member app-api；成功会话写 [SessionStore]
/// - 失败不落半登录态（TC-SYNC-104）
/// - logout 只清会话，不动本地业务数据（离线优先红线）
/// - 登录/跳过均不挡本地能力（currentSession null = 未登录照常用）
class RestAuthPort implements AuthPort {
  RestAuthPort({
    required Dio dio,
    required SessionStore store,
    String tenantId = '1',
  })  : _dio = dio,
        _store = store,
        _tenantId = tenantId;


  final Dio _dio;
  final SessionStore _store;
  final String _tenantId;

  @override
  Future<MemberSession?> currentSession() => _store.read();

  @override
  Future<MemberSession> login({
    required String username,
    required String password,
  }) async {
    // username 承载手机号（member 契约 mobile + password）
    final resp = await _dio.post<Map<String, dynamic>>(
      '/app-api/member/auth/login',
      data: {'mobile': username, 'password': password},
      options: Options(headers: {'tenant-id': _tenantId}),
    );
    final body = resp.data;
    if (body == null || body['code'] != 0 || body['data'] == null) {
      // TC-SYNC-104：明确失败、不落半登录态
      throw AuthFailureException(body?['msg']?.toString() ?? '登录失败');
    }
    final data = body['data'] as Map<String, dynamic>;
    final session = MemberSession(
      userId: data['userId'].toString(),
      tenantId: _tenantId,
      accessToken: data['accessToken'].toString(),
      refreshToken: data['refreshToken']?.toString(),
      displayName: data['nickname']?.toString(),
    );
    await _store.write(session);
    return session;
  }

  @override
  Future<void> logout() async {
    // 只清会话；本地提醒事项数据不动（离线优先）
    await _store.clear();
  }

  /// TC-SYNC-114：401 后走这条换新 token（`POST /app-api/member/auth/refresh-token?refreshToken=...`）。
  ///
  /// 语义边界：**成功才写回 store**；失败或没有 refreshToken 时**清会话**（下次 pull/push 直接
  /// 走未登录旁路，不再对着已过期的 token 反复撞 401）。刷新端点是 `@PermitAll`——
  /// 不带 Authorization 头也能调，所以不套 `_authed()`。
  @override
  Future<MemberSession?> refresh() async {
    final current = await _store.read();
    final refreshToken = current?.refreshToken;
    if (current == null || refreshToken == null || refreshToken.isEmpty) {
      return null;
    }
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/app-api/member/auth/refresh-token',
        queryParameters: {'refreshToken': refreshToken},
        options: Options(headers: {'tenant-id': _tenantId}),
      );
      final body = resp.data;
      if (body == null || body['code'] != 0 || body['data'] == null) {
        await _store.clear();
        return null;
      }
      final data = body['data'] as Map<String, dynamic>;
      final next = MemberSession(
        userId: (data['userId'] ?? current.userId).toString(),
        tenantId: _tenantId,
        accessToken: data['accessToken'].toString(),
        refreshToken: data['refreshToken']?.toString() ?? refreshToken,
        displayName: data['nickname']?.toString() ?? current.displayName,
      );
      await _store.write(next);
      return next;
    } on DioException {
      await _store.clear();
      return null;
    }
  }
}

/// 登录失败（HTTP 200 但业务码非 0 / 网络 DioException 原样上抛区分）。
final class AuthFailureException implements Exception {
  AuthFailureException(this.message);

  final String message;

  @override
  String toString() => 'AuthFailureException: $message';
}
