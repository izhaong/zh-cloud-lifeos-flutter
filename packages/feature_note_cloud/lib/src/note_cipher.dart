import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 锁定笔记加密（契约 §5：AES-GCM，pointycastle 4.0.0）。
///
/// 口令经 SHA-256 派生 256 位 key；输出 Base64(nonce(12) | mac(16) | 密文)。
class NoteCipher {
  const NoteCipher();

  static const int _nonceLength = 12;
  static const int _macBits = 128;

  String encrypt(String plaintext, String passphrase) {
    final key = _deriveKey(passphrase);
    final secureRandom = FortunaRandom()
      ..seed(KeyParameter(
          Uint8List.fromList(List<int>.generate(32, (_) => Random.secure().nextInt(256)))));
    final nonce = secureRandom.nextBytes(_nonceLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), _macBits, nonce, Uint8List(0)));
    // pointycastle 的 GCM process 输出已含 16 字节 tag（ciphertext || tag）
    final encrypted = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    final out = BytesBuilder()
      ..add(nonce)
      ..add(encrypted);
    return base64Encode(out.takeBytes());
  }

  String decrypt(String cipherText, String passphrase) {
    final raw = base64Decode(cipherText);
    if (raw.length <= _nonceLength + _macBits ~/ 8) {
      throw const FormatException('密文格式不正确');
    }
    final nonce = raw.sublist(0, _nonceLength);
    final payload = raw.sublist(_nonceLength); // ciphertext || tag
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(_deriveKey(passphrase)), _macBits, nonce, Uint8List(0)));
    return utf8.decode(cipher.process(payload));
  }

  Uint8List _deriveKey(String passphrase) {
    final digest = SHA256Digest().process(utf8.encode(passphrase));
    return Uint8List.fromList(digest);
  }
}
