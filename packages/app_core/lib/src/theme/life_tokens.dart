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

  /// Material 的 `ColorScheme` 只收静态 `Color`，故按亮度 + 对比度取包内的**四档**原值，
  /// 语义等价于 `CupertinoDynamicColor.resolveFrom(context)` 的结果。
  ///
  /// #348：此前只取 `color`/`darkColor`，Apple「提高对比度」打开后本应用毫无变化——
  /// 高对比两档从未被取用。现在四档齐取。
  static Color _resolve(
    CupertinoDynamicColor color,
    Brightness brightness, {
    bool highContrast = false,
  }) {
    if (brightness == Brightness.dark) {
      return highContrast ? color.darkHighContrastColor : color.darkColor;
    }
    return highContrast ? color.highContrastColor : color.color;
  }

  /// #195：Web（CanvasKit）不走系统字体，中文缺字形即方块。随包 Noto Sans SC
  /// 子集（apps/life_launcher/assets/fonts）作全局回退；拉丁仍用默认字体。
  static const cjkFontFallback = <String>['Noto Sans SC'];

  static TextStyle _withCjk(TextStyle style) =>
      style.copyWith(fontFamilyFallback: cjkFontFallback);

  /// #234：Cupertino 弹层用 SDK 常量样式，需单独挂回退。
  static const dialogTextStyle = TextStyle(fontFamilyFallback: cjkFontFallback);

  /// 根主题：业务 UI 默认走 Cupertino。亮度由调用方按系统值传入，
  /// 缺省保持亮档（与原行为一致）。
  static CupertinoThemeData cupertino([
    Brightness brightness = Brightness.light,
    bool highContrast = false,
  ]) {
    // 高对比档必须落成具体色值（CupertinoThemeData 不会自己按高对比解析动态色）；
    // 普通档仍传动态色，保持既有行为不变。
    final barBg =
        highContrast ? _resolve(surface, brightness, highContrast: true) : surface;
    final base = CupertinoThemeData(
      brightness: brightness,
      primaryColor: brand,
      primaryContrastingColor: const Color(0xFFFFFFFF),
      barBackgroundColor: barBg,
      scaffoldBackgroundColor: barBg,
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
  static ThemeData materialIsland([
    Brightness brightness = Brightness.light,
    bool highContrast = false,
  ]) {
    Color r(CupertinoDynamicColor c) =>
        _resolve(c, brightness, highContrast: highContrast);
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: r(brand),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: r(brand),
      onSecondary: const Color(0xFFFFFFFF),
      surface: r(surfaceSecondary),
      onSurface: r(onSurface),
      error: r(destructive),
      onError: const Color(0xFFFFFFFF),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: r(surface),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamilyFallback: cjkFontFallback),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: r(onSurface),
      ),
    );
  }
}
