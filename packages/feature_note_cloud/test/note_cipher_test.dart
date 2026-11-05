import 'package:feature_note_cloud/feature_note_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-KR-107（cloud 半）：AES-GCM 密文断言（契约 §5）。
void main() {
  test('AES-GCM 加密不落明文，可解密还原', () {
    const cipher = NoteCipher();
    const plain = '{"ops":[{"insert":"秘密正文\\n"}]}';
    final encrypted = cipher.encrypt(plain, 'pw');

    expect(encrypted, isNot(contains('秘密正文')));
    expect(cipher.decrypt(encrypted, 'pw'), plain);
  });

  test('错误口令无法解密', () {
    const cipher = NoteCipher();
    final encrypted = cipher.encrypt('hello', 'right');
    expect(() => cipher.decrypt(encrypted, 'wrong'), throwsA(anything));
  });
}
