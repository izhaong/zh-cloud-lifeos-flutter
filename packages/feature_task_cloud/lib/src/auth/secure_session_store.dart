import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:app_core/app_core.dart';

/// 会话安全存储（flutter_secure_storage；TC-SYNC-103）。
///
/// - keychain/keystore 落地（不入 SharedPreferences）
/// - 登出清 token **不清本地业务数据**（TC-SYNC-103 验收）
abstract interface class SessionStore {
  Future<MemberSession?> read();
  Future<void> write(MemberSession session);
  Future<void> clear();
}

/// flutter_secure_storage 实现。
final class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keySession = 'lifeos.member.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<MemberSession?> read() async {
    final raw = await _storage.read(key: _keySession);
    if (raw == null || raw.isEmpty) return null;
    // 简单编码 userId|tenantId|token|name（token 不含分隔符；name 可空）
    final parts = raw.split('|');
    if (parts.length < 3) return null;
    return MemberSession(
      userId: parts[0],
      tenantId: parts[1],
      accessToken: parts[2],
      displayName: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
    );
  }

  @override
  Future<void> write(MemberSession session) async {
    await _storage.write(
      key: _keySession,
      value: [
        session.userId,
        session.tenantId,
        session.accessToken,
        session.displayName ?? '',
      ].join('|'),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _keySession);
  }
}
