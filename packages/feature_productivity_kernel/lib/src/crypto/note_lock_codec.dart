// 锁定备忘录的客户端加密（#395；契约 §5 / 矩阵 N18「降级：客户端 AES-GCM」）。
//
// 现状问题：`locked` 只是个 UI 标志——正文 Delta 仍以明文 JSON 落库，解锁口令
// 也不校验（输入任意非空字符串就算「解锁」）。也就是说「锁定」没有任何保护。
//
// 本编解码器把密文**自包含**在一个信封里：
//
//   {"v":1,"salt":"<b64 16B>","verifier":"<b64>","ct":"<b64 nonce|mac|密文>"}
//
// - `salt` 每条备忘录独立随机，`verifier = SHA-256(salt | passphrase)` 用来**校验口令**，
//   所以不需要另存密码哈希表（数据库里没有可直接比对的弱哈希）；
// - `ct` 是 AES-GCM（256 位 key = SHA-256(salt | passphrase)）的 Base64，
//   布局 nonce(12) | 密文 | tag(16)，与 pointycastle 的 GCM 输出一致。
//
// 口令不经任何持久化；解密失败抛 [NoteLockException]，调用方据此提示「密码错误」。
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 口令错误 / 密文损坏。
class NoteLockException implements Exception {
  const NoteLockException(this.message);

  final String message;

  @override
  String toString() => 'NoteLockException: $message';
}

/// 锁定正文的加解密（纯函数，无状态）——仓储层与编辑器共用同一实现。
abstract final class NoteLockCodec {
  static const int _version = 1;
  static const int _nonceLength = 12;
  static const int _saltLength = 16;
  static const int _macBits = 128;

  /// 该字符串是否已是锁定信封（用于判断「要不要解密」）。
  static bool isSealed(String value) {
    final trimmed = value.trimLeft();
    if (!trimmed.startsWith('{')) {
      return false;
    }
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map && decoded['v'] == _version && decoded['ct'] is String;
    } on FormatException {
      return false;
    }
  }

  /// 加密正文；返回信封 JSON（可直接写进 `Note.bodyDelta`）。
  static String seal(String plaintext, String passphrase) {
    if (passphrase.isEmpty) {
      throw const NoteLockException('口令不能为空');
    }
    final salt = _randomBytes(_saltLength);
    final key = _deriveKey(passphrase, salt);
    final nonce = _randomBytes(_nonceLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), _macBits, nonce, Uint8List(0)),
      );
    final sealed = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    final payload = BytesBuilder()
      ..add(nonce)
      ..add(sealed);
    return jsonEncode({
      'v': _version,
      'salt': base64Encode(salt),
      'verifier': base64Encode(_verifier(passphrase, salt)),
      'ct': base64Encode(payload.takeBytes()),
    });
  }

  /// 解密正文；口令不符或密文损坏抛 [NoteLockException]。
  static String open(String envelope, String passphrase) {
    final Map<String, dynamic> parsed;
    try {
      final decoded = jsonDecode(envelope);
      if (decoded is! Map<String, dynamic>) {
        throw const NoteLockException('密文格式不正确');
      }
      parsed = decoded;
    } on FormatException {
      throw const NoteLockException('密文格式不正确');
    }
    if (parsed['v'] != _version) {
      throw const NoteLockException('不支持的密文版本');
    }
    final Uint8List saltRaw;
    final Uint8List raw;
    try {
      saltRaw = base64Decode(parsed['salt'] as String);
      raw = base64Decode(parsed['ct'] as String);
    } on FormatException {
      // base64 坏掉也归为「密文格式不正确」，别把底层异常抛给 UI
      throw const NoteLockException('密文格式不正确');
    }
    final expected = parsed['verifier'] as String;
    // 先比校验器：口令错时给「密码错误」，而不是让它走到 GCM 的 MAC 失败
    if (!_constantTimeEquals(
        expected, base64Encode(_verifier(passphrase, saltRaw)))) {
      throw const NoteLockException('密码错误');
    }
    if (raw.length <= _nonceLength + _macBits ~/ 8) {
      throw const NoteLockException('密文格式不正确');
    }
    final nonce = raw.sublist(0, _nonceLength);
    final body = raw.sublist(_nonceLength);
    try {
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(_deriveKey(passphrase, saltRaw)),
            _macBits,
            nonce,
            Uint8List(0),
          ),
        );
      return utf8.decode(cipher.process(body));
    } on Exception {
      // MAC 校验失败也归为口令/密文问题，不把底层异常泄露给 UI
      throw const NoteLockException('密码错误或密文已损坏');
    }
  }

  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    final digest = SHA256Digest();
    digest.update(salt, 0, salt.length);
    digest.update(utf8.encode(passphrase), 0, utf8.encode(passphrase).length);
    final out = Uint8List(digest.digestSize);
    digest.doFinal(out, 0);
    return out;
  }

  static Uint8List _verifier(String passphrase, Uint8List salt) {
    final digest = SHA256Digest();
    const label = 'lifeos-note-lock-v1';
    digest.update(utf8.encode(label), 0, label.length);
    digest.update(salt, 0, salt.length);
    digest.update(utf8.encode(passphrase), 0, utf8.encode(passphrase).length);
    final out = Uint8List(digest.digestSize);
    digest.doFinal(out, 0);
    return out;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
