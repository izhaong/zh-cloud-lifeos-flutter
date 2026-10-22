/// 窗口尺寸类（Material window size class 三档）。
///
/// 纯宽度判定，不带平台分支：断点只影响外壳布局，不改变业务逻辑。
/// 单一取值点，feature_task 与生活台壳均经由本类取档，叶子内容 widget 禁读断点。
enum WindowSizeClass {
  /// 紧凑：<600dp，iPhone 竖屏、Split View 窄窗 → 栈导航单栏。
  compact,

  /// 中等：600–1199dp，iPad 竖屏 / 11" 横屏 → 分栏二栏。
  medium,

  /// 展开：≥1200dp，iPad 12.9"/13" 横屏、macOS 默认窗 → 可开第三列详情。
  expanded;

  /// 唯一断点来源；[width] 为逻辑像素宽度（dp）。
  static WindowSizeClass fromWidth(double width) {
    if (width >= 1200) return WindowSizeClass.expanded;
    if (width >= 600) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }

  /// 是否应呈现分栏（medium/expanded）。
  bool get isPaneLayout => this != WindowSizeClass.compact;

  /// 是否可展开第三列「详细信息」（expanded）。
  bool get supportsDetailPane => this == WindowSizeClass.expanded;
}
