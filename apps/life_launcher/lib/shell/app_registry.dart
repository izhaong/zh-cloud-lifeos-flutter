import 'package:cupertino_ui/cupertino_ui.dart';

/// 壳层「已安装应用」静态注册表（§1.4：首期第一方应用）。
///
/// Phase 5 接入 H1 目录后改为动态安装清单；本表是壳层唯一事实源，
/// Tab 偏好只引用 [AppEntry.id]，不内联标题/图标。
class AppEntry {
  const AppEntry({
    required this.id,
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.branchPath,
    this.isPlaceholder = false,
  });

  /// 稳定 id（Tab 偏好持久化引用；勿改）。
  final String id;

  final String title;
  final IconData icon;
  final IconData selectedIcon;

  /// 对应 GoRouter StatefulShellRoute 分支路径。
  final String branchPath;

  /// 是否为占位应用（feature_* 未拆入：日历/习惯）。
  final bool isPlaceholder;
}

/// 首期已装应用（顺序 = 默认 Tab 顺序，不含「更多」）。
///
/// 「更多」不是 AppEntry：它由壳层固定渲染、永远最右、不可移除（§1.4）。
const List<AppEntry> installedApps = [
  AppEntry(
    id: 'task',
    title: '任务',
    icon: CupertinoIcons.checkmark_circle,
    selectedIcon: CupertinoIcons.checkmark_circle_fill,
    branchPath: '/',
  ),
  AppEntry(
    id: 'calendar',
    title: '日历',
    icon: CupertinoIcons.calendar,
    selectedIcon: CupertinoIcons.calendar,
    branchPath: '/calendar',
    isPlaceholder: false,
  ),
  AppEntry(
    id: 'note',
    title: '记录',
    icon: CupertinoIcons.doc_text,
    selectedIcon: CupertinoIcons.doc_text_fill,
    branchPath: '/note',
  ),
  AppEntry(
    id: 'habit',
    title: '习惯',
    icon: CupertinoIcons.heart,
    selectedIcon: CupertinoIcons.heart_fill,
    branchPath: '/habits',
    isPlaceholder: true,
  ),
];

/// Tab 常用上限（不含「更多」）——§1.4。
const int maxPinnedTabs = 5;

AppEntry appById(String id) =>
    installedApps.firstWhere((e) => e.id == id, orElse: () => installedApps.first);
