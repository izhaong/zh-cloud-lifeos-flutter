import 'member_session.dart';

/// 认证端口：开源仓仅 Noop；真实实现在 `*_cloud`。
abstract interface class AuthPort {
  Future<MemberSession?> currentSession();
  Future<MemberSession> login({
    required String username,
    required String password,
  });
  Future<void> logout();
}

/// 开源 / 本地默认：永不登录成功，供跳过登录路径。
final class NoopAuthPort implements AuthPort {
  const NoopAuthPort();

  @override
  Future<MemberSession?> currentSession() async => null;

  @override
  Future<MemberSession> login({
    required String username,
    required String password,
  }) {
    throw UnsupportedError('NoopAuthPort: 登录仅在 cloud 实现中可用');
  }

  @override
  Future<void> logout() async {}
}
