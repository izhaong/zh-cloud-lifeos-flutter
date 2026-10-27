import 'member_session.dart';

/// 认证端口：开源仓仅 Noop；真实实现在 `*_cloud`。
abstract interface class AuthPort {
  Future<MemberSession?> currentSession();
  Future<MemberSession> login({
    required String username,
    required String password,
  });
  Future<void> logout();

  /// 用当前会话里的 refreshToken 换一张新 accessToken（TC-SYNC-114）。
  /// 成功返回新会话（并已写回 store）；不可刷新或换失败返回 null——
  /// 调用方（如 RestSyncPort 的 401 分支）拿到 null 就当"刷新通道走不通"处理，
  /// 不许把 null 静默当成"刷新成功"。
  Future<MemberSession?> refresh();
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

  @override
  Future<MemberSession?> refresh() async => null;
}
