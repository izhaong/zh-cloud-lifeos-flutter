import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_note/feature_note.dart';
import 'package:feature_task/feature_task.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_registry.dart';
import '../shell/life_shell.dart';
import '../shell/more_page.dart';
import '../shell/placeholder_page.dart';
import '../shell/route_not_found_page.dart';
import '../shell_providers.dart';

/// 全仓唯一 GoRouter：单一逻辑路由表；断点只换外壳布局，不换路由结构。
///
/// - `/`：任务 Tab（列表首页）；子路由 `/list/:listId` 仍在壳内 → **壳应用栏常显**
/// - 旧 `/tasks*` 重定向到壳内路径（兼容深链）
///
/// 分支序与 [installedApps] 注册表一致（「更多」恒最末 = [LifeShell.moreBranchIndex]）。
/// 路由重定向的纯函数（便于单测；parity#187）。
///
/// - `/task`、`/tasks` → `/`：任务分支挂在根路径，此前没有同名深链，
///   手输/收藏 `#/task` 会直接落到 go_router 的英文 404；
/// - 旧 `/tasks/list/<id>` → `/list/<id>`；
/// - 冷启动落在 `/` 但任务未固定 → 首个固定分支或 `/more`。
String? lifeRedirect(String loc, List<String> pinnedIds) {
  if (loc == '/task' || loc == '/tasks') return '/';
  if (loc.startsWith('/tasks/list/')) {
    final id = loc.substring('/tasks/list/'.length);
    return '/list/$id';
  }
  if (loc == '/' && !pinnedIds.contains('task')) {
    return pinnedIds.isEmpty ? '/more' : appById(pinnedIds.first).branchPath;
  }
  return null;
}

GoRouter buildLifeRouter(WidgetRef ref) {
  final pinned = ref
      .read(pinnedTabsServiceProvider)
      .read()
      .map(appById)
      .toList();

  final pinnedIds = [for (final e in pinned) e.id];

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) => lifeRedirect(state.matchedLocation, pinnedIds),
    // parity#187：未知路由给中文 Cupertino 兜底，且不回显 GoException 原文
    errorBuilder: (context, state) => RouteNotFoundPage(
      onHome: () => context.go('/'),
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return LifeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const TaskTabEntry(),
                routes: [
                  GoRoute(
                    path: 'list/:listId',
                    builder: (context, state) =>
                        TaskTabEntry(listId: state.pathParameters['listId']),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarTabEntry(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/note',
                builder: (context, state) => const NoteTabEntry(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/habits',
                builder: (context, state) => const PlaceholderPage(
                  title: '习惯',
                  subtitle: '即将推出',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MorePage(),
              ),
            ],
          ),
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
    final sizeClass = WindowSizeClass.fromWidth(
      MediaQuery.sizeOf(context).width,
    );
    // 只有 expanded（≥1200，三栏）才渲染 inspector：`_ThreePane` 是唯一接收
    // `selectedItemId` 的布局，`_TwoPane` 收到 id 也不画任何东西。此前这里判
    // `isPaneLayout`（medium + expanded 都算），于是 600–1199 二栏档点行只改了
    // 一个没人读的字段 —— 详情/编辑入口整档不可达（flutter#159，P0）。
    // 二栏与紧凑端走同一条模态详情：Apple 在 iPad 分栏与 Mac 窄窗下点提醒
    // 同样能进详情，编辑入口不因窗宽落在中间档而消失。
    if (sizeClass == WindowSizeClass.expanded) {
      setState(() => _selectedItemId = item.id);
      return;
    }
    // #481：中等档用锚定在列表右侧的浮动详情窗（列表仍可见），
    // 紧凑档按 iPhone 口径整页推入详情；两者都不再用遮挡列表的底部抽屉。
    if (sizeClass == WindowSizeClass.medium) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: '关闭详情',
        barrierColor: const Color(0x14000000),
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (dialogContext, _, _) => SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  maxHeight: 560,
                ),
                child: DecoratedBox(
                  key: const ValueKey('detail_popover'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_detailPopoverRadius),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_detailPopoverRadius),
                    child: ReminderDetailPane(
                      item: item,
                      onSaved: (updated) {
                        ref.read(reminderRepositoryProvider).upsertItem(updated);
                      },
                      onClose: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    // 紧凑档：整页详情（iPhone 口径），列表通过返回键回到。
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (pageContext) => ReminderDetailPane(
          item: item,
          onSaved: (updated) {
            ref.read(reminderRepositoryProvider).upsertItem(updated);
          },
          onClose: () => Navigator.of(pageContext).pop(),
        ),
      ),
    );
  }

  static const _detailPopoverRadius = 14.0;

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.fromWidth(
      MediaQuery.sizeOf(context).width,
    );
    // 宽屏：默认落到「今天」，避免空「选择一个列表」（线框 Pad/客户端起点）
    final openListId =
        widget.listId ?? (sizeClass.isPaneLayout ? 'smart.today' : null);

    return TaskScaffold(
      openListId: openListId,
      selectedItemId: _selectedItemId,
      // T-05（cursor R1-2）：设置「开启云同步」→ 登录页（cloud 侧实现；跳过不挡本地）
      onOpenCloudLogin: () => Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute<bool>(
          fullscreenDialog: true,
          builder: (_) => const LifeMaterialIsland(child: CloudLoginPage()),
        ),
      ),
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
