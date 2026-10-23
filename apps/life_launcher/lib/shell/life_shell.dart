import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_registry.dart';
import '../shell_providers.dart';

/// 生活台壳：飞书式应用栏，「更多」永远最右/最下（§1.4）。
///
/// - **compact 竖屏**：底部 [NavigationBar]
/// - **横屏或 medium/expanded（Pad 类）**：左侧 [NavigationRail]
///
/// Tab 由 [installedApps] 注册表 + 用户偏好（[pinnedTabsServiceProvider]）
/// 派生；偏好只隐藏 destination，不动 StatefulShellRoute 分支。
/// 「更多」分支索引恒为 [moreBranchIndex]（router 分支序固定）。
/// 打开未固定应用或当前分支不可见时，高亮回退「更多」（飞书同款）。
class LifeShell extends ConsumerWidget {
  const LifeShell({super.key, required this.navigationShell});

  /// 「更多」在 StatefulShellRoute 分支里的索引（分支序与 installedApps 一致 +1）。
  static const int moreBranchIndex = 3;

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(pinnedTabsServiceProvider);
    final badges = ref.watch(shellBadgeCountsProvider);
    // 响应编辑写即生效：偏好变更驱动应用栏重建（AnimatedBuilder 监听 changes）
    return AnimatedBuilder(
      animation: service.changes,
      builder: (context, _) =>
          _buildShell(context, service.read(), badges),
    );
  }

  Widget _buildShell(
    BuildContext context,
    List<String> pinnedIds,
    Map<String, int> badges,
  ) {
    final pinned = pinnedIds.map(appById).toList(growable: false);

    final currentBranch = navigationShell.currentIndex;
    final selectedVisible = _selectedVisibleIndex(
      currentBranch,
      pinned,
    );

    final sizeClass =
        WindowSizeClass.fromWidth(MediaQuery.sizeOf(context).width);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    // 横屏或 Pad 类宽屏 → 左轨；compact 竖屏 → 底栏
    final useLeftRail = isLandscape || sizeClass.isPaneLayout;

    void onSelect(int visibleIndex) {
      final branch = visibleIndex == pinned.length
          ? moreBranchIndex
          : _branchIndexOf(pinned[visibleIndex]);
      navigationShell.goBranch(branch, initialLocation: false);
    }

    if (useLeftRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedVisible,
              onDestinationSelected: onSelect,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final app in pinned) _railDestinationFor(app, badges),
                _moreRailDestination(badges, pinned),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedVisible,
        onDestinationSelected: onSelect,
        destinations: [
          for (final app in pinned) _destinationFor(app, badges),
          _moreDestination(badges, pinned),
        ],
      ),
    );
  }

  /// 当前高亮（可见序）：当前分支被取消固定 → 回退「更多」（= pinned.length）。
  static int _selectedVisibleIndex(
    int currentBranch,
    List<AppEntry> pinned,
  ) {
    for (var i = 0; i < pinned.length; i++) {
      if (_branchIndexOf(pinned[i]) == currentBranch) return i;
    }
    return pinned.length; // 更多
  }

  /// 分支索引 = 注册表序（router 分支顺序与 installedApps 一致）。
  static int _branchIndexOf(AppEntry app) =>
      installedApps.indexWhere((e) => e.id == app.id);

  NavigationDestination _destinationFor(
    AppEntry app,
    Map<String, int> badges,
  ) {
    final count = badges[app.id] ?? 0;
    return NavigationDestination(
      icon: _badgeIcon(app.icon, count),
      selectedIcon: _badgeIcon(app.selectedIcon, count),
      label: app.title,
    );
  }

  NavigationDestination _moreDestination(
    Map<String, int> badges,
    List<AppEntry> pinned,
  ) {
    // 「更多」汇总未固定在 Tab 可见位的应用未读（§1.4 聚合规则）
    final pinnedIds = {for (final e in pinned) e.id};
    final overflow = badges.entries
        .where((e) => !pinnedIds.contains(e.key))
        .fold<int>(0, (sum, e) => sum + e.value);
    return NavigationDestination(
      icon: _badgeIcon(Icons.grid_view_outlined, overflow),
      selectedIcon: _badgeIcon(Icons.grid_view, overflow),
      label: '更多',
    );
  }

  NavigationRailDestination _railDestinationFor(
    AppEntry app,
    Map<String, int> badges,
  ) {
    final count = badges[app.id] ?? 0;
    return NavigationRailDestination(
      icon: _badgeIcon(app.icon, count),
      selectedIcon: _badgeIcon(app.selectedIcon, count),
      label: Text(app.title),
    );
  }

  NavigationRailDestination _moreRailDestination(
    Map<String, int> badges,
    List<AppEntry> pinned,
  ) {
    final pinnedIds = {for (final e in pinned) e.id};
    final overflow = badges.entries
        .where((e) => !pinnedIds.contains(e.key))
        .fold<int>(0, (sum, e) => sum + e.value);
    return NavigationRailDestination(
      icon: _badgeIcon(Icons.grid_view_outlined, overflow),
      selectedIcon: _badgeIcon(Icons.grid_view, overflow),
      label: const Text('更多'),
    );
  }

  /// 徽标图标：Material Badge 包 Icon（Tab 与更多行复用同一渲染）。
  static Widget _badgeIcon(IconData icon, int count) {
    if (count <= 0) return Icon(icon);
    return Badge.count(count: count, child: Icon(icon));
  }
}
