import 'package:flutter/material.dart';

/// 跨 App 一致的账号/壳层设计令牌（各业务可覆盖皮肤）。
abstract final class LifeTokens {
  static const brand = Color(0xFF007AFF);
  static const surface = Color(0xFFF2F2F7);
  static const onSurface = Color(0xFF1C1C1E);

  static ThemeData light() {
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
