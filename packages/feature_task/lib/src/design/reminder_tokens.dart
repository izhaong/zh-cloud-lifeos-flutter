import 'package:cupertino_ui/cupertino_ui.dart';

/// Apple Reminders 参考图取样得到的桌面视觉 token。
///
/// 只放颜色/渐变/间距等纯常量，避免各 widget 各自硬编码。
abstract final class ReminderTokens {
  static const systemBlue = Color(0xFF007AFF);
  static const systemRed = Color(0xFFFF3B30);
  static const systemOrange = Color(0xFFFF9500);
  static const systemGreen = Color(0xFF34C759);

  // parity#157：Apple 语义色按亮/暗成对声明，绘制点用 CupertinoDynamicColor
  // .resolve(...) 取值；此前是纯亮色常量，暗色下侧栏/主区仍白（#157）。
  static const labelPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF000000),
    darkColor: Color(0xFFFFFFFF),
  );
  static const labelSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8E8E93),
    darkColor: Color(0xFF98989F),
  );
  static const labelTertiary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC7C7CC),
    darkColor: Color(0xFF5C5C60),
  );

  static const separator = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE5E5EA),
    darkColor: Color(0xFF38383A),
  );
  static const sidebarBg = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF5F5F5),
    darkColor: Color(0xFF1C1C1E),
  );
  static const mainBg = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF000000),
  );
  static const windowBg = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF000000),
  );

  static const radiusCard = 10.0;
  static const radiusSheet = 16.0;
  static const radiusListIcon = 6.0;

  static const cardPadding = EdgeInsets.all(10);
  static const cardGap = 8.0;
  static const sidebarPadding = EdgeInsets.fromLTRB(16, 4, 16, 8);

  /// 桌面侧栏宽度：参考图约为窗口宽的 23.5%，1024/1280/1532 分别约 240/300/360。
  static double sidebarWidth(double maxWidth) =>
      (maxWidth * 0.235).clamp(240.0, 360.0);

  static LinearGradient smartGradient(String id) => switch (id) {
        'smart.today' => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF82B5EE), Color(0xFF74AEEB)],
          ),
        'smart.scheduled' => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF09291), Color(0xFFEE8684)],
          ),
        'smart.all' => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6C6C6C), Color(0xFF5E5E5E)],
          ),
        'smart.flagged' => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4BE93), Color(0xFFF4B987)],
          ),
        'smart.urgent' => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF08CA5), Color(0xFFEF809D)],
          ),
        'smart.completed' => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF979DA3), Color(0xFF8A9096)],
          ),
        'smart.assigned' => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9CD9A6), Color(0xFF94D69E)],
          ),
        _ => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8E8E93), Color(0xFF7C7C82)],
          ),
      };
}
