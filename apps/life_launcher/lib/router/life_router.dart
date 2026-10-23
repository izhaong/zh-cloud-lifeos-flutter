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
/// 紧凑端列表首页 → 点列表 `push` 到 `/list/:id`（仍在壳内）；宽屏分栏不跳路由。
class TaskTabEntry extends ConsumerWidget {
  const TaskTabEntry({super.key, this.listId});

  final String? listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TaskScaffold(
      openListId: listId,
      onOpenList: (id) => context.push('/list/$id'),
      onBack: listId == null
          ? null
          : () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
    );
  }
}
