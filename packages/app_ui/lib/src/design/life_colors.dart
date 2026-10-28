import 'package:cupertino_ui/cupertino_ui.dart';

/// Apple 系统色（Epic #126 / A1）。
///
/// 全部用 [CupertinoDynamicColor] 表达，亮/暗由系统解算——业务代码不需要再写
/// `withBrightness` 的两份值。字面色只应出现在本文件或各包的 design 令牌里，
/// 由 `scripts/check_ui_boundary.dart` 的 C3 零容忍门禁把关。
abstract final class LifeColors {
  /// Apple systemBlue。
  static const systemBlue = Color(0xFF007AFF);

  /// Apple systemRed。
  static const systemRed = Color(0xFFFF3B30);

  /// 次要文本（secondaryLabel）。
  static const labelSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8E8E93),
    darkColor: Color(0xFF98989F),
  );

  /// 三级文本/占位（tertiaryLabel）。
  static const labelTertiary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC7C7CC),
    darkColor: Color(0xFF5C5C60),
  );

  /// 分隔线（separator）。
  static const separator = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC6C6C8),
    darkColor: Color(0xFF38383A),
  );
}
