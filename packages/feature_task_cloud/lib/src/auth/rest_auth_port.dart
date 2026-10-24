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
}

/// 登录失败（HTTP 200 但业务码非 0 / 网络 DioException 原样上抛区分）。
final class AuthFailureException implements Exception {
  AuthFailureException(this.message);

  final String message;

  @override
  String toString() => 'AuthFailureException: $message';
}
