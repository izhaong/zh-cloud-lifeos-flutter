import 'dart:ui' show Brightness;

import 'package:app_core/app_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// 暗色档用例。断言值全部取自 cupertino_ui 1.1.4 `lib/src/colors.dart` 源码原值，
/// 可按行号复算，不凭记忆：
///   systemBlue                       light 0xFF007AFF / dark 0xFF0A84FF   (:133-136)
///   systemGroupedBackground          light 0xFFF2F2F7 / dark 0xFF000000   (:559-560)
///   secondarySystemGroupedBackground light 0xFFFFFFFF / dark 0xFF1C1C1E   (:575-576)
///   label                            light 0xFF000000 / dark 0xFFFFFFFF   (:383-384)
void main() {
  group('LifeTokens 亮/暗双档', () {
    test('亮档不变（不破坏 #128 的契约钉）', () {
      final island = LifeTokens.materialIsland();
      expect(island.colorScheme.primary.toARGB32(), 0xFF007AFF);
      expect(island.scaffoldBackgroundColor.toARGB32(), 0xFFF2F2F7);
      expect(island.colorScheme.surface.toARGB32(), 0xFFFFFFFF);
      expect(island.colorScheme.onSurface.toARGB32(), 0xFF000000);
      expect(LifeTokens.cupertino().primaryColor.toARGB32(), 0xFF007AFF);
    });

    test('暗档要解算出 Apple 官方暗值，而不是沿用亮值', () {
      final dark = LifeTokens.materialIsland(Brightness.dark);
      expect(dark.colorScheme.primary.toARGB32(), 0xFF0A84FF);
      expect(dark.scaffoldBackgroundColor.toARGB32(), 0xFF000000);
      expect(dark.colorScheme.surface.toARGB32(), 0xFF1C1C1E);
      expect(dark.colorScheme.onSurface.toARGB32(), 0xFFFFFFFF);
      expect(dark.colorScheme.error.toARGB32(), isNot(0xFF007AFF));
    });

    test('根主题可按亮度切换（此前硬钉 Brightness.light）', () {
      expect(LifeTokens.cupertino(Brightness.dark).brightness, Brightness.dark);
      expect(LifeTokens.cupertino().brightness, Brightness.light);
    });

    test('亮暗两档必须真的解算出不同值（同值即说明动态色没接上）', () {
      expect(LifeTokens.materialIsland(Brightness.dark).colorScheme.primary,
          isNot(LifeTokens.materialIsland(Brightness.light).colorScheme.primary));
    });
  });
}
