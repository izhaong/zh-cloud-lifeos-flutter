import 'package:flutter/material.dart';

import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/life_shell.dart';
import '../shell/more_page.dart';
import '../shell/placeholder_page.dart';

/// 全仓唯一 GoRouter：单一逻辑路由表；断点只换外壳布局，不换路由结构。
///
/// - `/`：生活台壳（StatefulShellRoute.indexedStack，底部 Tab≤4 + 更多最右）
/// - `/tasks`：紧凑端全屏提醒事项（shell 外顶层路由 → 无双底栏）
/// - `/tasks/list/:listId`：全屏单列表（紧凑栈导航）
GoRouter buildLifeRouter() {
  return GoRouter(
    initialLocation: '/',
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
              builder: (context, state) =>
                  const PlaceholderPage(title: '日历', subtitle: 'feature_calendar 待拆入'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/habits',
              builder: (context, state) =>
                  const PlaceholderPage(title: '习惯', subtitle: 'feature_habit 待拆入'),
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
