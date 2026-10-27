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
  static ThemeData materialIsland() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brand,
        brightness: Brightness.light,
      ),
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
