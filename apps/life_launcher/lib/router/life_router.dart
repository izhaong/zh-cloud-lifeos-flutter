import 'package:flutter/material.dart';

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
/// - `/`：生活台壳（StatefulShellRoute.indexedStack，分支序=installedApps+更多）
/// - `/tasks`、`/tasks/list/:listId`：紧凑端全屏提醒事项（shell 外顶层路由）
///
/// 分支序与 [installedApps] 注册表一致（「更多」恒最末 = [LifeShell.moreBranchIndex]）。
GoRouter buildLifeRouter(WidgetRef ref) {
  final pinned =
      ref.read(pinnedTabsServiceProvider).read().map(appById).toList();

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // 冷启动落在 '/'（任务分支 0）且任务被取消固定 → 跳首个固定分支；
      // 全不固定 → /more（底栏高亮有落点，不悬空）。
      if (state.matchedLocation == '/' && !pinned.any((e) => e.id == 'task')) {
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
      GoRoute(
        path: '/tasks',
        builder: (context, state) => const TaskFullScreen(),
      ),
      GoRoute(
        path: '/tasks/list/:listId',
        builder: (context, state) =>
            TaskFullScreen(listId: state.pathParameters['listId']),
      ),
    ],
  );
}

/// 壳内「任务」Tab：宽屏直接呈现分栏任务区（不外跳）；
/// 紧凑端显示入口概览，点列表全屏推入（无双底栏）。
class TaskTabEntry extends ConsumerWidget {
  const TaskTabEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TaskScaffold(
      openListId: null,
      onOpenList: (listId) => context.go('/tasks/list/$listId'),
    );
  }
}

/// 全屏提醒事项体验（shell 外顶层路由）：紧凑端隐藏生活台底栏。
class TaskFullScreen extends ConsumerWidget {
  const TaskFullScreen({super.key, this.listId});

  final String? listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TaskScaffold(
      openListId: listId,
      onOpenList: (id) => context.go('/tasks/list/$id'),
    );
  }
}
