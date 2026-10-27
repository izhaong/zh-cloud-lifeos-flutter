import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/material.dart';

/// 跨 App 一致的账号/壳层设计令牌（各业务可覆盖皮肤）。
abstract final class LifeTokens {
  static const brand = Color(0xFF007AFF);
  static const surface = Color(0xFFF2F2F7);
  static const onSurface = Color(0xFF1C1C1E);

  /// 根主题：业务 UI 默认走 Cupertino。
  static CupertinoThemeData cupertino() {
    return const CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: brand,
      primaryContrastingColor: Color(0xFFFFFFFF),
      barBackgroundColor: surface,
      scaffoldBackgroundColor: surface,
    );
  }

  /// Material 岛主题：只服务 kalender / flutter_quill 等第三方内核。
  ///
  /// 不用 `ColorScheme.fromSeed`：M3 会把 007AFF 调成灰蓝（实测 primary=ff445e91），
  /// 与 Cupertino 主色分叉。
  static ThemeData materialIsland() {
    const colorScheme = ColorScheme.light(
      primary: brand,
      onPrimary: Color(0xFFFFFFFF),
      secondary: brand,
      onSecondary: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: onSurface,
      error: Color(0xFFFF3B30),
      onError: Color(0xFFFFFFFF),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: onSurface,
      ),
    );
  }
}
