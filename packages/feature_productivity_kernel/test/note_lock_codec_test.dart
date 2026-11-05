// TC-NOTE-KR-107（#395）：锁定备忘录必须**真的加密**，而不是只挂个标志。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

const _delta = '{"ops":[{"insert":"机密：银行卡 6222\\n"}]}';

void main() {
  test('TC-NOTE-KR-107 封/开可逆，且密文里没有明文', () {
    final sealed = NoteLockCodec.seal(_delta, 'correct horse');

    expect(NoteLockCodec.isSealed(sealed), isTrue);
    expect(sealed.contains('银行卡'), isFalse,
        reason: '落库的是密文；明文不得出现在信封里（这正是本 Issue 的核心）');
    expect(sealed.contains('6222'), isFalse);

    expect(NoteLockCodec.open(sealed, 'correct horse'), _delta);
  });

  test('TC-NOTE-KR-107 口令错误必须失败（且错误信息可判）', () {
    final sealed = NoteLockCodec.seal(_delta, 'correct horse');
    expect(
      () => NoteLockCodec.open(sealed, 'wrong horse'),
      throwsA(isA<NoteLockException>()),
    );
  });

  test('同一明文两次加密的密文不同（salt/nonce 随机）', () {
    final a = NoteLockCodec.seal(_delta, 'p@ss');
    final b = NoteLockCodec.seal(_delta, 'p@ss');
    expect(a, isNot(equals(b)));
    expect(NoteLockCodec.open(a, 'p@ss'), _delta);
    expect(NoteLockCodec.open(b, 'p@ss'), _delta);
  });

  test('密文被篡改要失败（GCM MAC）', () {
    final sealed = NoteLockCodec.seal(_delta, 'p@ss');
    final tampered = sealed.replaceFirst('"ct":"', '"ct":"X');
    expect(
      () => NoteLockCodec.open(tampered, 'p@ss'),
      throwsA(isA<NoteLockException>()),
    );
  });

  test('非信封内容不误判为密文', () {
    expect(NoteLockCodec.isSealed(_delta), isFalse);
    expect(NoteLockCodec.isSealed(''), isFalse);
    expect(NoteLockCodec.isSealed('{"ops":[]}'), isFalse);
  });

  test('空口令拒绝加密（否则等于没锁）', () {
    expect(() => NoteLockCodec.seal(_delta, ''), throwsA(isA<NoteLockException>()));
  });
}
