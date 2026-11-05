import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #195：CJK 回退字体必须随包且已在 pubspec 声明，否则 Web 端仍会向
/// fonts.gstatic.com 按需拉子集，缺字形即方块。
void main() {
  test('Noto Sans SC 子集随包并已声明', () {
    final font = File('assets/fonts/NotoSansSC-Regular.ttf');
    expect(font.existsSync(), isTrue, reason: '字体文件缺失');
    expect(
      font.lengthSync(),
      greaterThan(1 * 1024 * 1024),
      reason: '子集不应是空壳（GB2312 覆盖约 2MB）',
    );

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: Noto Sans SC'));
    expect(pubspec, contains('assets/fonts/NotoSansSC-Regular.ttf'));

    final license = File('assets/fonts/OFL.txt');
    expect(license.existsSync(), isTrue, reason: 'OFL 许可文本必须随包');
    expect(license.readAsStringSync(), contains('SIL Open Font License'));
  });
}
