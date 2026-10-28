import 'package:cupertino_ui/cupertino_ui.dart';

/// 日历侧视觉令牌（Epic #126 / B3）。
///
/// 取值原则：**亮色 = 原字面值**（迁移前后亮色外观逐像素不变），再补一份暗色
/// 对应值，让暗色随系统解算——此前这些颜色是写死的亮色，暗色下会糊。
///
/// 只放颜色；排版/间距等到 A2 阶段再收。
abstract final class CalendarTokens {
  /// Apple systemBlue（选中边、今天、主按钮）。
  static const systemBlue = Color(0xFF007AFF);

  /// Apple systemRed（删除、节假日初一）。
  static const systemRed = Color(0xFFFF3B30);

  /// 正文强调色：亮 1C1C1E（原字面值）/ 暗 白。
  ///
  /// 原代码把 `1C1C1E` 当正文色写死，那是 iOS **暗色**的次级背景值，亮色下
  /// 勉强能看、暗色下几乎没有对比——这里保留亮色观感并补上暗色。
  static const labelStrong = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1C1C1E),
    darkColor: Color(0xFFFFFFFF),
  );

  /// 次要文本：亮 8E8E93 / 暗 98989F（Apple secondaryLabel）。
  static const labelSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8E8E93),
    darkColor: Color(0xFF98989F),
  );

  /// 发丝线：亮 E5E5EA / 暗 3A3A3C。
  static const hairline = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE5E5EA),
    darkColor: Color(0xFF3A3A3C),
  );

  /// 分组背景：亮 F2F2F7 / 暗 1C1C1E（Apple systemGroupedBackground）。
  static const groupedBackground = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF1C1C1E),
  );
  /// 卡片/浮层表面：亮 FFFFFF / 暗 1C1C1E。
  static const surface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1C1E),
  );

  /// 更淡一级的正文色：亮 3C3C43 / 暗 EBEBF5（原代码写死的 3C3C43 是暗色取值）。
  static const labelSubtle = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF3C3C43),
    darkColor: Color(0xFFEBEBF5),
  );

  /// 次级窗口底：亮 F7F7F9 / 暗 000000。
  static const windowBackground = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF7F7F9),
    darkColor: Color(0xFF000000),
  );

  /// 三级灰：亮 C7C7CC / 暗 48484A（Apple systemGrey3）。
  static const grey3 = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC7C7CC),
    darkColor: Color(0xFF48484A),
  );

  /// 分隔线（不透明档）：亮 C6C6C8 / 暗 38383A（Apple separator）。
  static const separator = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC6C6C8),
    darkColor: Color(0xFF38383A),
  );

  /// 输入框/胶囊底：亮 E9E9EB / 暗 2C2C2E。
  static const chipBackground = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE9E9EB),
    darkColor: Color(0xFF2C2C2E),
  );
}
