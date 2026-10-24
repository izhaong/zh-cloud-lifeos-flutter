import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:app_core/app_core.dart';

/// 会话安全存储（flutter_secure_storage；TC-SYNC-103）。
///
/// - keychain/keystore 落地（不入 SharedPreferences）
/// - 登出清 token **不清本地业务数据**（TC-SYNC-103 验收）
/// - 编码 = JSON（管道分隔在 token/name 含 `|` 时会截断——cursor PR#17 阻断1）
abstract interface class SessionStore {
  Future<MemberSession?> read();
  Future<void> write(MemberSession session);
  Future<void> clear();
}

/// flutter_secure_storage 实现（JSON 编码，任意字符安全）。
final class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keySession = 'lifeos.member.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<MemberSession?> read() async {
    final raw = await _storage.read(key: _keySession);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final userId = map['userId'];
      final tenantId = map['tenantId'];
      final accessToken = map['accessToken'];
      if (userId is! String || tenantId is! String || accessToken is! String) {
        return null;
      }
      return MemberSession(
        userId: userId,
        tenantId: tenantId,
        accessToken: accessToken,
        displayName: map['displayName'] is String
            ? map['displayName'] as String
            : null,
      );
    } catch (_) {
      return null; // 损坏数据按未登录处理（离线优先，不炸）
    }
  }

  @override
  Future<void> write(MemberSession session) async {
    await _storage.write(
      key: _keySession,
      value: jsonEncode({
        'userId': session.userId,
        'tenantId': session.tenantId,
        'accessToken': session.accessToken,
        'displayName': session.displayName,
      }),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _keySession);
  }
}
