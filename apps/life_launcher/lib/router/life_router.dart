import 'package:flutter/material.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_registry.dart';
import '../shell/life_shell.dart';
import '../shell/more_page.dart';
import '../shell/placeholder_page.dart';
import '../shell_providers.dart';

/// 全仓唯一 GoRouter：单一逻辑路由表；断点只换外壳布局，不换路由结构。
///
/// - `/`：任务 Tab（列表首页）；子路由 `/list/:listId` 仍在壳内 → **壳应用栏常显**
/// - 旧 `/tasks*` 重定向到壳内路径（兼容深链）
///
/// 分支序与 [installedApps] 注册表一致（「更多」恒最末 = [LifeShell.moreBranchIndex]）。
GoRouter buildLifeRouter(WidgetRef ref) {
  final pinned =
      ref.read(pinnedTabsServiceProvider).read().map(appById).toList();

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      // 兼容旧全屏路径 → 壳内
      if (loc == '/tasks') return '/';
      if (loc.startsWith('/tasks/list/')) {
        final id = loc.substring('/tasks/list/'.length);
        return '/list/$id';
      }
      // 冷启动落在 '/' 且任务未固定 → 跳首个固定分支或 /more
      if (loc == '/' && !pinned.any((e) => e.id == 'task')) {
        return pinned.isEmpty ? '/more' : pinned.first.branchPath;
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return LifeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const TaskTabEntry(),
              routes: [
                GoRoute(
                  path: 'list/:listId',
                  builder: (context, state) => TaskTabEntry(
                    listId: state.pathParameters['listId'],
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const PlaceholderPage(
                  title: '日历', subtitle: '占位 · feature_calendar 待拆入'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/habits',
              builder: (context, state) => const PlaceholderPage(
                  title: '习惯', subtitle: '占位 · feature_habit 待拆入'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/more',
              builder: (context, state) => const MorePage(),
            ),
          ]),
        ],
      ),
    ],
  );
}

/// 壳内「任务」Tab：始终嵌在 [LifeShell] 内，应用栏常显（竖屏底栏 / 横屏或 Pad 左轨）。
///
/// 紧凑端列表首页 → 点列表 `push` 到 `/list/:id`（仍在壳内）；
/// 点行 → 详情模态（壳底栏仍在）；宽屏分栏就地切换 + inspector。
class TaskTabEntry extends ConsumerStatefulWidget {
  const TaskTabEntry({super.key, this.listId});

  final String? listId;

  @override
  ConsumerState<TaskTabEntry> createState() => _TaskTabEntryState();
}

class _TaskTabEntryState extends ConsumerState<TaskTabEntry> {
  String? _selectedItemId;

  Future<void> _openDetail(ReminderItem item) async {
    final sizeClass =
        WindowSizeClass.fromWidth(MediaQuery.sizeOf(context).width);
    if (sizeClass.isPaneLayout) {
      setState(() => _selectedItemId = item.id);
      return;
    }
    // 紧凑端：模态详细信息（不盖掉壳应用栏）
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.98,
          builder: (_, scrollController) {
            return ReminderDetailPane(
              item: item,
              onSaved: (updated) {
                ref.read(reminderRepositoryProvider).upsertItem(updated);
              },
              onClose: () => Navigator.of(sheetContext).pop(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizeClass =
        WindowSizeClass.fromWidth(MediaQuery.sizeOf(context).width);
    // 宽屏：默认落到「今天」，避免空「选择一个列表」（线框 Pad/客户端起点）
    final openListId = widget.listId ??
        (sizeClass.isPaneLayout ? 'smart.today' : null);

    return TaskScaffold(
      openListId: openListId,
      selectedItemId: _selectedItemId,
      onOpenList: (id) {
        setState(() => _selectedItemId = null);
        if (sizeClass.isPaneLayout) {
          context.go('/list/$id');
        } else {
          context.push('/list/$id');
        }
      },
      onSelectItem: _openDetail,
      onBack: widget.listId == null
          ? null
          : () {
              setState(() => _selectedItemId = null);
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
    );
  }
}
