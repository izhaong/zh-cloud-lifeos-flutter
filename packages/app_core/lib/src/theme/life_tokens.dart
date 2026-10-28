import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/material.dart';

/// 跨 App 一致的账号/壳层设计令牌（各业务可覆盖皮肤）。
///
/// 颜色一律取 `cupertino_ui` 的 Apple 动态色，不在本仓手抄 hex 对：包内每个色都带
/// 亮/暗/高对比四档原值（`cupertino_ui-1.1.4/lib/src/colors.dart`）。逐处抄值正是
/// `feature_task` 一度出现 31 个漂移 hex 的成因。
abstract final class LifeTokens {
  /// Apple 系统色（动态四档）。light 档解析值与旧静态常量一致。
  static const brand = CupertinoColors.systemBlue;
  static const surface = CupertinoColors.systemGroupedBackground;
  static const surfaceSecondary = CupertinoColors.secondarySystemGroupedBackground;
  static const onSurface = CupertinoColors.label;
  static const onSurfaceSecondary = CupertinoColors.secondaryLabel;
  static const separator = CupertinoColors.separator;
  static const destructive = CupertinoColors.systemRed;

  /// Material 的 `ColorScheme` 只收静态 `Color`，故按亮度取包内的分档原值，
  /// 语义等价于 `CupertinoDynamicColor.resolveFrom` 在给定亮度下的结果。
  static Color _resolve(CupertinoDynamicColor color, Brightness brightness) =>
      brightness == Brightness.dark ? color.darkColor : color.color;

  /// #195：Web（CanvasKit）不走系统字体，中文缺字形即方块。随包 Noto Sans SC
  /// 子集（apps/life_launcher/assets/fonts）作全局回退；拉丁仍用默认字体。
  static const cjkFontFallback = <String>['Noto Sans SC'];

  static TextStyle _withCjk(TextStyle style) =>
      style.copyWith(fontFamilyFallback: cjkFontFallback);

  /// 根主题：业务 UI 默认走 Cupertino。亮度由调用方按系统值传入，
  /// 缺省保持亮档（与原行为一致）。
  static CupertinoThemeData cupertino([Brightness brightness = Brightness.light]) {
    final base = CupertinoThemeData(
      brightness: brightness,
      primaryColor: brand,
      primaryContrastingColor: const Color(0xFFFFFFFF),
      barBackgroundColor: surface,
      scaffoldBackgroundColor: surface,
    );
    final t = base.textTheme;
    return base.copyWith(
      textTheme: CupertinoTextThemeData(
        primaryColor: brand,
        textStyle: _withCjk(t.textStyle),
        actionTextStyle: _withCjk(t.actionTextStyle),
        actionSmallTextStyle: _withCjk(t.actionSmallTextStyle),
        tabLabelTextStyle: _withCjk(t.tabLabelTextStyle),
        navTitleTextStyle: _withCjk(t.navTitleTextStyle),
        navLargeTitleTextStyle: _withCjk(t.navLargeTitleTextStyle),
        navActionTextStyle: _withCjk(t.navActionTextStyle),
        pickerTextStyle: _withCjk(t.pickerTextStyle),
        dateTimePickerTextStyle: _withCjk(t.dateTimePickerTextStyle),
      ),
    );
  }

  /// Material 岛主题：只服务 kalender / flutter_quill 等第三方内核。
  ///
  /// 不用 `ColorScheme.fromSeed`：M3 会把 007AFF 调成灰蓝（实测 primary=ff445e91），
  /// 与 Cupertino 主色分叉。
  static ThemeData materialIsland([Brightness brightness = Brightness.light]) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: _resolve(brand, brightness),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: _resolve(brand, brightness),
      onSecondary: const Color(0xFFFFFFFF),
      surface: _resolve(surfaceSecondary, brightness),
      onSurface: _resolve(onSurface, brightness),
      error: _resolve(destructive, brightness),
      onError: const Color(0xFFFFFFFF),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _resolve(surface, brightness),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamilyFallback: cjkFontFallback),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _resolve(onSurface, brightness),
      ),
    );
  }
}
