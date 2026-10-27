import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_registry.dart';
import 'shell_badge.dart';
import '../shell_providers.dart';

/// 生活台壳：Apple 式应用栏，「更多」永远最右/最下（§1.4）。
///
/// - **compact 竖屏**：底部 [CupertinoTabBar]
/// - **横屏或 medium/expanded（Pad 类）**：左侧固定宽侧栏
///
/// Tab 由 [installedApps] 注册表 + 用户偏好（[pinnedTabsServiceProvider]）
/// 派生；偏好只隐藏 destination，不动 StatefulShellRoute 分支。
/// 「更多」分支索引恒为 [moreBranchIndex]（router 分支序固定）。
/// 打开未固定应用或当前分支不可见时，高亮回退「更多」（飞书同款）。
class LifeShell extends ConsumerWidget {
  const LifeShell({super.key, required this.navigationShell});

  /// 「更多」在 StatefulShellRoute 分支里的索引（分支序与 installedApps 一致 +1）。
  static int get moreBranchIndex => installedApps.length;

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(pinnedTabsServiceProvider);
    final badges = ref.watch(shellBadgeCountsProvider);
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
    final selectedVisible = _selectedVisibleIndex(currentBranch, pinned);

    final sizeClass =
        WindowSizeClass.fromWidth(MediaQuery.sizeOf(context).width);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final useLeftRail = isLandscape || sizeClass.isPaneLayout;

    void onSelect(int visibleIndex) {
      final branch = visibleIndex == pinned.length
          ? moreBranchIndex
          : _branchIndexOf(pinned[visibleIndex]);
      navigationShell.goBranch(branch, initialLocation: false);
    }

    final background =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);

    if (useLeftRail) {
      final pinnedIdsSet = {for (final e in pinned) e.id};
      final overflow = badges.entries
          .where((e) => !pinnedIdsSet.contains(e.key))
          .fold<int>(0, (sum, e) => sum + e.value);
      return CupertinoPageScaffold(
        backgroundColor: background,
        child: Row(
          children: [
            SizedBox(
              key: const ValueKey('shell_sidebar'),
              width: 240,
              child: _AppSidebar(
                pinned: pinned,
                badges: badges,
                overflow: overflow,
                selectedIndex: selectedVisible,
                onSelect: onSelect,
              ),
            ),
            Container(
              width: 0.5,
              color: CupertinoColors.separator.resolveFrom(context),
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    final pinnedIdsSet = {for (final e in pinned) e.id};
    final overflow = badges.entries
        .where((e) => !pinnedIdsSet.contains(e.key))
        .fold<int>(0, (sum, e) => sum + e.value);

    return CupertinoPageScaffold(
      backgroundColor: background,
      child: Column(
        children: [
          Expanded(child: navigationShell),
          CupertinoTabBar(
            currentIndex: selectedVisible,
            onTap: onSelect,
            items: [
              for (final app in pinned)
                BottomNavigationBarItem(
                  icon: _badgeIcon(
                    app.icon,
                    badges[app.id] ?? 0,
                    'shell_badge_${app.id}',
                  ),
                  activeIcon: _badgeIcon(
                    app.selectedIcon,
                    badges[app.id] ?? 0,
                    'shell_badge_${app.id}',
                  ),
                  label: app.title,
                ),
              BottomNavigationBarItem(
                icon: _badgeIcon(
                  CupertinoIcons.square_grid_2x2,
                  overflow,
                  'shell_badge_more',
                ),
                activeIcon: _badgeIcon(
                  CupertinoIcons.square_grid_2x2_fill,
                  overflow,
                  'shell_badge_more',
                ),
                label: '更多',
              ),
            ],
          ),
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
    return pinned.length;
  }

  /// 分支索引 = 注册表序（router 分支顺序与 installedApps 一致）。
  static int _branchIndexOf(AppEntry app) =>
      installedApps.indexWhere((e) => e.id == app.id);

  static Widget _badgeIcon(IconData icon, int count, String key) {
    if (count <= 0) return Icon(icon, size: 26);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 26),
        Positioned(
          right: -7,
          top: -5,
          child: ShellBadge(key: ValueKey(key), count: count),
        ),
      ],
    );
  }
}

/// 宽屏侧栏：Apple 式行 + 0.5px 分隔线与选中圆角底。
class _AppSidebar extends StatelessWidget {
  const _AppSidebar({
    required this.pinned,
    required this.badges,
    required this.overflow,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<AppEntry> pinned;
  final Map<String, int> badges;
  final int overflow;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        children: [
          for (var i = 0; i < pinned.length; i++)
            _SidebarItem(
              key: ValueKey('shell_rail_${pinned[i].id}'),
              id: pinned[i].id,
              icon: pinned[i].icon,
              selectedIcon: pinned[i].selectedIcon,
              label: pinned[i].title,
              selected: selectedIndex == i,
              badgeCount: badges[pinned[i].id] ?? 0,
              onTap: () => onSelect(i),
            ),
          _SidebarItem(
            key: const ValueKey('shell_rail_more'),
            id: 'more',
            icon: CupertinoIcons.square_grid_2x2,
            selectedIcon: CupertinoIcons.square_grid_2x2_fill,
            label: '更多',
            selected: selectedIndex == pinned.length,
            badgeCount: overflow,
            onTap: () => onSelect(pinned.length),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    super.key,
    required this.id,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final String id;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final blue = CupertinoColors.systemBlue.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        alignment: Alignment.centerLeft,
        borderRadius: BorderRadius.circular(8),
        onPressed: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? blue.withValues(alpha: 0.14) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 18,
                  color: selected ? blue : secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? blue : labelColor,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  ShellBadge(
                    key: ValueKey('shell_badge_$id'),
                    count: badgeCount,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
