import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:app_core/app_core.dart';
import 'package:app_ui/app_ui.dart';

import 'design/reminder_tokens.dart';
import 'print/task_list_pdf.dart';
import 'providers.dart';
import 'widgets/new_list_dialog.dart';
import 'widgets/reminder_detail_pane.dart';
import 'widgets/reminder_row.dart';
import 'widgets/shared_list_pane.dart';
import 'widgets/list_share_sheet.dart';
import 'widgets/section_editor_sheet.dart';
import 'widgets/smart_list_card.dart';
import 'widgets/task_settings_sheet.dart';
import 'widgets/task_shortcuts.dart';
import 'widgets/task_sidebar.dart';

/// 智能视图新建的落点（#245）。
///
/// Apple：智能列表里新建提醒落到账户的 **Default List**；默认列表未设置或
/// 已失效（指向被删的列表）时用第一个可用自有列表。此前写死 `list.personal`，
/// 既无视用户设置，又在该列表不存在时生成不可见的孤儿条目。
///
/// [lists] 可含智能列表（会被过滤）；无任何自有列表时回退旧行为，保证
/// 依旧写在一个明确的 id 上（由仓库/服务端兜底）。
String resolveSmartCreateListId({
  required List<ReminderList> lists,
  String? preferredId,
}) {
  final own = lists.where((l) => !l.isSmart).toList(growable: false);
  if (preferredId != null && own.any((l) => l.id == preferredId)) {
    return preferredId;
  }
  if (own.isNotEmpty) {
    return own.first.id;
  }
  return 'list.personal';
}

/// 打开设置界面：优先用组合根注入的独立窗口（#577），否则应用内页面。
///
/// 窗口打开失败由注入方回退应用内页面，这里不判平台、不吞异常。
Future<void> openTaskSettings(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onOpenCloudLogin,
}) {
  final opener = ref.read(taskSettingsWindowOpenerProvider);
  if (opener != null) {
    return opener(context, onOpenCloudLogin: onOpenCloudLogin);
  }
  return showTaskSettingsSheet(
    context,
    onOpenCloudLogin: onOpenCloudLogin == null
        ? null
        : (_) => onOpenCloudLogin(),
  );
}

/// 任务区自适应脚手架：单一逻辑内容，按 [WindowSizeClass] 只换外壳布局。
///
/// - compact：单栏（首页列表视图；进列表/详情由路由栈推入）
/// - medium：二栏（侧栏 | 当前列表）
/// - expanded：三栏（侧栏 | 当前列表 | 详细信息，详情有选中才占位）
///
/// 三端共用同一批内容 widget，断点不产生业务逻辑分叉。
class TaskScaffold extends ConsumerWidget {
  const TaskScaffold({
    super.key,
    this.openListId,
    this.selectedItemId,
    this.onOpenList,
    this.onSelectItem,
    this.onBack,
    this.onOpenCloudLogin,
  });

  /// 紧凑端首页概览（列表首页）：智能列表卡片 + 我的列表。
  final String? openListId;

  /// 三栏第三列选中的提醒 id；空 = 不显示详情栏。
  final String? selectedItemId;

  /// 「开启云同步」入口（T-05 TC-SYNC-102）：由宿主（launcher/cloud 组合根）
  /// 注入登录页跳转；空 = 显示「登录后可用」弱化文案（F1 边界：feature_task 不依赖 cloud）。
  final VoidCallback? onOpenCloudLogin;

  /// 点开列表的回调（紧凑端由壳层路由推栈，仍在生活台底栏内）。
  final ValueChanged<String>? onOpenList;

  /// 点开提醒条目的回调（紧凑端推详情模态）。
  final ValueChanged<ReminderItem>? onSelectItem;

  /// 紧凑端列表页返回（壳层提供；保持壳应用栏常显）。
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizeClass = WindowSizeClass.fromWidth(
      MediaQuery.of(context).size.width,
    );
    final listsAsync = ref.watch(reminderListsProvider);

    return listsAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (lists) {
        // #575：把当前可见清单发布给壳的「显示 → 前往」子菜单（壳不存第二份状态）。
        _publishGoToLists(ref, lists);
        // 快捷键层（⌘N 新建 / ⌘F 搜索）包裹三档外壳；触屏端无物理键不影响
        final panes = TaskShortcuts(
          child: switch (sizeClass) {
            WindowSizeClass.compact =>
              openListId == null
                  ? _CompactPane(
                      lists: lists,
                      onOpenList: onOpenList,
                      onSelectItem: onSelectItem,
                      onOpenCloudLogin: onOpenCloudLogin,
                    )
                  : _CompactListPane(
                      lists: lists,
                      openListId: openListId!,
                      onSelectItem: onSelectItem,
                      onBack: onBack,
                    ),
            WindowSizeClass.medium => _TwoPane(
              lists: lists,
              openListId: openListId,
              onOpenList: onOpenList,
              onSelectItem: onSelectItem,
              onOpenCloudLogin: onOpenCloudLogin,
            ),
            WindowSizeClass.expanded =>
              ref.watch(taskViewModeProvider)
                  ? _ThreePane(
                      lists: lists,
                      openListId: openListId,
                      selectedItemId: selectedItemId,
                      onOpenList: onOpenList,
                      onSelectItem: onSelectItem,
                      onOpenCloudLogin: onOpenCloudLogin,
                    )
                  : _TwoPane(
                      lists: lists,
                      openListId: openListId,
                      onOpenList: onOpenList,
                      onSelectItem: onSelectItem,
                      onOpenCloudLogin: onOpenCloudLogin,
                    ),
          },
        );
        final panesWithMenu = _MenuGoToListener(
          request: ref.read(lifeMenuGoToRequestProvider),
          onOpen: onOpenList,
          child: panes,
        );
        final undo = ref.watch(completionUndoProvider);
        if (undo == null) return panesWithMenu;
        return Column(
          children: [
            ColoredBox(
              color: CupertinoDynamicColor.resolve(
                ReminderTokens.windowBg,
                context,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Text('已完成'),
                    ),
                  ),
                  CupertinoButton(
                    key: const ValueKey('undo_complete'),
                    onPressed: () {
                      // cursor 两轮评审收口：撤销=只回退「完成相关」+ 滚动过的 dueAt，
                      // 其余字段（标题/备注/旗标/优先级）一律保当前最新行——
                      // 不整条快照回写（R1 静默丢数据），也不无视滚动（R2 空操作）。
                      ref.read(completionUndoProvider.notifier).clear();
                      final repo = ref.read(reminderRepositoryProvider);
                      repo.watchItems().first.then((all) async {
                        final latest = all.firstWhere(
                          (e) => e.id == undo.id,
                          orElse: () => undo,
                        );
                        final restored = latest
                            .copyWith(isCompleted: false)
                            .copyWith(completedAt: ReminderItem.clear)
                            .copyWith(dueAt: undo.dueAt);
                        await repo.upsertItem(restored);
                      });
                    },
                    child: const Text('撤销'),
                  ),
                ],
              ),
            ),
            Expanded(child: panesWithMenu),
          ],
        );
      },
    );
  }
}

/// #575：把当前清单快照写给壳菜单；比较后再写，避免每帧触发菜单重建。
void _publishGoToLists(WidgetRef ref, List<ReminderList> lists) {
  final notifier = ref.read(lifeMenuGoToListsProvider);
  if (notifier == null) return;
  final targets = [
    for (final l in lists) LifeMenuGoToTarget(id: l.id, title: l.title),
  ];
  final old = notifier.value;
  var same = old.length == targets.length;
  if (same) {
    for (var i = 0; i < old.length; i++) {
      if (old[i].id != targets[i].id || old[i].title != targets[i].title) {
        same = false;
        break;
      }
    }
  }
  if (same) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    notifier.value = targets;
  });
}

/// #575：「显示 → 前往」点击后切列表；菜单只写 id，切换由页面做。
class _MenuGoToListener extends StatefulWidget {
  const _MenuGoToListener({
    required this.request,
    required this.onOpen,
    required this.child,
  });

  final ValueNotifier<String?>? request;
  final ValueChanged<String>? onOpen;
  final Widget child;

  @override
  State<_MenuGoToListener> createState() => _MenuGoToListenerState();
}

class _MenuGoToListenerState extends State<_MenuGoToListener> {
  @override
  void initState() {
    super.initState();
    widget.request?.addListener(_onRequest);
  }

  @override
  void didUpdateWidget(covariant _MenuGoToListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request != widget.request) {
      oldWidget.request?.removeListener(_onRequest);
      widget.request?.addListener(_onRequest);
    }
  }

  @override
  void dispose() {
    widget.request?.removeListener(_onRequest);
    super.dispose();
  }

  void _onRequest() {
    final id = widget.request?.value;
    if (id == null) return;
    widget.request?.value = null;
    widget.onOpen?.call(id);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 紧凑单栏：iPhone 列表首页（智能列表卡片 + 我的列表 + 添加列表）。
/// 搜索有词时切换为「全部」过滤结果（线框：首页 → 搜索结果 / 空态）。
class _CompactPane extends ConsumerWidget {
  const _CompactPane({
    required this.lists,
    required this.onOpenList,
    this.onSelectItem,
    this.onOpenCloudLogin,
  });

  final List<ReminderList> lists;
  final ValueChanged<String>? onOpenList;
  final ValueChanged<ReminderItem>? onSelectItem;

  /// #594：紧凑档此前没有任何设置入口 ⇒ 「开启云同步 → 登录」在手机上走不通。
  /// 齿轮与宽屏侧栏齿轮共用同一个 `openTaskSettings`，不新增页面、不改信息架构层级。
  final VoidCallback? onOpenCloudLogin;

  /// #491：Apple 的列表编辑（改名/颜色/类型）。图标需领域字段，按矩阵 M2 后置。
  Future<void> _editLists(
    BuildContext context,
    WidgetRef ref,
    List<ReminderList> mine,
  ) async {
    if (mine.isEmpty) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => LifeAlertDialog(
          title: const Text('编辑列表'),
          content: const Text('还没有可编辑的列表'),
          actions: [
            LifeDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('好'),
            ),
          ],
        ),
      );
      return;
    }
    final target = mine.length == 1
        ? mine.first
        : await showCupertinoModalPopup<ReminderList>(
            context: context,
            builder: (ctx) => CupertinoActionSheet(
              title: const Text('编辑列表'),
              actions: [
                for (final l in mine)
                  CupertinoActionSheetAction(
                    key: ValueKey('edit_pick_${l.id}'),
                    onPressed: () => Navigator.of(ctx).pop(l),
                    child: Text(l.title),
                  ),
              ],
              cancelButton: CupertinoActionSheetAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
            ),
          );
    if (target == null || !context.mounted) return;
    await showEditListDialog(
      context,
      list: target,
      onSave: (updated) =>
          ref.read(reminderRepositoryProvider).upsertList(updated),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smart = lists
        .where(
          (e) =>
              e.isSmart &&
              e.id != 'smart.trash' &&
              // 分配事项按批次裁定不出现在任务 UI（TC-API-121 降级口径；
              // 负向断言见 compact_home_visual_test / wireframe_gaps_test）
              e.id != 'smart.assigned',
        )
        .toList(growable: false);
    // #588：置顶的自有清单离开「我的列表」，与智能清单同排占一张卡（与桌面侧栏同一分流）。
    final userLists = lists
        .where((e) => !e.isSmart)
        .toList(growable: false);
    final split = splitPinnedUserLists(userLists);
    final cardItems = [...smart, ...split.cards];
    final mine = split.mine;
    // 编辑选择器要能选中任何自有清单（含已置顶的）——置顶只是换位置，不是隐藏；
    // 顺序与屏幕一致：先卡片区那批，再「我的列表」那批。
    final editable = [...split.cards, ...split.mine];
    final trash = lists.where((e) => e.id == 'smart.trash').firstOrNull;
    final hasGrocery = userLists.any(
      (e) => e.listType == ReminderListType.grocery,
    );
    final query = ref.watch(searchQueryProvider).trim();
    final searching = query.isNotEmpty;

    // iOS 提醒事项「列表」首页：大标题 + 搜索 + 智能卡片 + 我的列表。
    // 嵌在生活台壳内时，壳应用栏常显；本页不再另起全屏路由。
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(
        ReminderTokens.windowBg,
        context,
      ),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoDynamicColor.resolve(
          ReminderTokens.windowBg,
          context,
        ),
        automaticallyImplyLeading: false,
        middle: const Text('列表'),
        // #594：齿轮（设置）与原 ⋯（编辑列表）并排，两者都留在应用栏里，不加第二层导航。
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              key: const ValueKey('compact_settings'),
              padding: EdgeInsets.zero,
              onPressed: () => openTaskSettings(
                context,
                ref,
                onOpenCloudLogin: onOpenCloudLogin,
              ),
              child: const Icon(CupertinoIcons.gear, size: 22),
            ),
            CupertinoButton(
              key: const ValueKey('home_edit_placeholder'),
              onPressed: () => _editLists(context, ref, editable),
              child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
            ),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          CupertinoTextField(
            key: const ValueKey('home_search'),
            onChanged: (v) => ref.read(searchQueryProvider.notifier).set(v),
            placeholder: '搜索',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                CupertinoIcons.search,
                size: 20,
                color: ReminderTokens.labelSecondary,
              ),
            ),
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                ReminderTokens.separator,
                context,
              ),
              borderRadius: BorderRadius.circular(LifeRadius.lg),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          ),
          const SizedBox(height: 16),
          if (searching)
            _HomeSearchResults(query: query, onSelectItem: onSelectItem)
          else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 84,
              ),
              itemCount: cardItems.length,
              itemBuilder: (context, i) {
                final list = cardItems[i];
                return SmartListCard(
                  list: list,
                  selected: false,
                  compact: true,
                  onTap: () => onOpenList?.call(list.id),
                );
              },
            ),
            // #258：建议列表开关关闭后首页也不再推荐
            if (!hasGrocery &&
                (ref.watch(taskPreferenceProvider).value?.suggestLists ?? true))
              GestureDetector(
                key: const ValueKey('suggested_grocery_home'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _createSuggestedGrocery(ref),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.cart_fill,
                        color: ReminderTokens.systemGreen,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('建议列表：日常采购')),
                      CupertinoButton(
                        key: const ValueKey('suggested_grocery_home_add'),
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.all(2),
                        onPressed: () => _createSuggestedGrocery(ref),
                        child: const Icon(
                          CupertinoIcons.add_circled_solid,
                          color: ReminderTokens.systemGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              '我的列表',
              style: TextStyle(
                fontSize: 14,
                color: ReminderTokens.labelSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(LifeRadius.xl),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < mine.length; i++) ...[
                    if (i > 0) const _Hairline(indent: 52),
                    _HomeListRow(
                      list: mine[i],
                      onTap: () => onOpenList?.call(mine[i].id),
                    ),
                  ],
                  const _Hairline(indent: 52),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showNewListDialog(
                      context,
                      onCreate: (list) =>
                          ref.read(reminderRepositoryProvider).upsertList(list),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.add_circled_solid,
                            color: ReminderTokens.systemBlue,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            '添加列表',
                            style: TextStyle(
                              color: ReminderTokens.systemBlue,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (trash != null) ...[
                    const _Hairline(indent: 52),
                    _HomeListRow(
                      list: trash,
                      isTrash: true,
                      onTap: () => onOpenList?.call(trash.id),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void _createSuggestedGrocery(WidgetRef ref) {
    final id = 'list.grocery.${DateTime.now().millisecondsSinceEpoch}';
    ref
        .read(reminderRepositoryProvider)
        .upsertList(ReminderList.createGroceryList(id: id, title: '日常采购'));
  }
}

/// 首页搜索结果：复用「全部」过滤；空态文案对齐线框。
class _HomeSearchResults extends ConsumerWidget {
  const _HomeSearchResults({required this.query, this.onSelectItem});

  final String query;
  final ValueChanged<ReminderItem>? onSelectItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(filteredItemsForListProvider('smart.all'));
    final repo = ref.watch(reminderRepositoryProvider);
    return itemsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (e, _) => Text('加载失败：$e'),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                '无结果',
                key: ValueKey('search_empty'),
                style: TextStyle(color: ReminderTokens.labelSecondary),
              ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(LifeRadius.xl),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const _Hairline(indent: 56),
                ReminderRow(
                  item: items[i],
                  now: ref.read(clockProvider)(),
                  // #446：设置决定全天提醒是否按逾期显示
                  allDayAsOverdue:
                      ref
                          .watch(taskPreferenceProvider)
                          .value
                          ?.allDayRemindersOverdue ??
                      false,
                  onToggleCompleted: () => completeReminder(ref, items[i]),
                  onToggleFlagged: () => repo.toggleFlagged(items[i].id),
                  onTap: () => onSelectItem?.call(items[i]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 紧凑端单列表（壳内子路由）：「‹ 列表」返回 + 列表内容；生活台底栏仍由壳提供。
class _CompactListPane extends StatelessWidget {
  const _CompactListPane({
    required this.lists,
    required this.openListId,
    this.onSelectItem,
    this.onBack,
  });

  final List<ReminderList> lists;
  final String openListId;
  final ValueChanged<ReminderItem>? onSelectItem;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final list = lists.where((e) => e.id == openListId).firstOrNull;
    if (list == null) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoDynamicColor.resolve(
          ReminderTokens.windowBg,
          context,
        ),
        child: const Center(child: Text('列表不存在')),
      );
    }
    return ListContentPane(
      list: list,
      onSelectItem: onSelectItem,
      listTitles: {for (final l in lists) l.id: l.title},
      leading: onBack == null
          ? null
          : CupertinoButton(
              onPressed: onBack,
              minimumSize: Size.zero,
              padding: const EdgeInsets.only(left: 4),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.back, size: 18),
                  SizedBox(width: 2),
                  Text('列表', style: TextStyle(fontSize: 17)),
                ],
              ),
            ),
    );
  }
}

/// 中等二栏：侧栏 | 列表内容（线框 Pad；侧栏可隐藏铺满主区）。
class _TwoPane extends ConsumerWidget {
  const _TwoPane({
    required this.lists,
    required this.openListId,
    required this.onOpenList,
    this.onSelectItem,
    this.onOpenCloudLogin,
  });

  final List<ReminderList> lists;
  final String? openListId;
  final ValueChanged<String>? onOpenList;
  final ValueChanged<ReminderItem>? onSelectItem;
  final VoidCallback? onOpenCloudLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = lists.where((e) => e.id == openListId).firstOrNull;
    final sidebarVisible = ref.watch(sidebarVisibleProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebarWidth = ReminderTokens.sidebarWidth(constraints.maxWidth);
        return Row(
          key: const ValueKey('two_pane'),
          children: [
            if (sidebarVisible) ...[
              SizedBox(
                width: sidebarWidth,
                child: TaskSidebar(
                  lists: lists,
                  selectedListId: openListId,
                  onSelect: (l) => onOpenList?.call(l.id),
                  onSelectSharedList: (s) => onOpenList?.call(s.listId),
                  onAddList: () => showNewListDialog(
                    context,
                    onCreate: (list) =>
                        ref.read(reminderRepositoryProvider).upsertList(list),
                  ),
                  onToggleSidebar: () =>
                      ref.read(sidebarVisibleProvider.notifier).toggle(),
                  onOpenSettings: () => openTaskSettings(
                    context,
                    ref,
                    // 恒非 null 闭包会破坏「空=弱化文案」契约——传本体（null 即弱化）
                    onOpenCloudLogin: onOpenCloudLogin,
                  ),
                ),
              ),
              const _VerticalHairline(),
            ],
            Expanded(
              child: current == null
                  ? _SharedOrEmptyPane(
                      openListId: openListId,
                      showSidebarButton: !sidebarVisible,
                      onShowSidebar: () =>
                          ref.read(sidebarVisibleProvider.notifier).set(true),
                    )
                  : ListContentPane(
                      list: current,
                      onSelectItem: onSelectItem,
                      listTitles: {for (final l in lists) l.id: l.title},
                      leading: sidebarVisible
                          ? null
                          : Semantics(
                              label: '显示侧栏',
                              button: true,
                              child: CupertinoButton(
                                key: const ValueKey('show_sidebar'),
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.all(6),
                                onPressed: () => ref
                                    .read(sidebarVisibleProvider.notifier)
                                    .set(true),
                                child: const Icon(
                                  CupertinoIcons.sidebar_left,
                                  size: 20,
                                ),
                              ),
                            ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// 展开三栏：侧栏 | 列表内容 | 详细信息（客户端 inspector）。
class _ThreePane extends ConsumerStatefulWidget {
  const _ThreePane({
    required this.lists,
    required this.openListId,
    required this.selectedItemId,
    required this.onOpenList,
    this.onSelectItem,
    this.onOpenCloudLogin,
  });

  final List<ReminderList> lists;
  final String? openListId;
  final String? selectedItemId;
  final ValueChanged<String>? onOpenList;
  final VoidCallback? onOpenCloudLogin;
  final ValueChanged<ReminderItem>? onSelectItem;

  @override
  ConsumerState<_ThreePane> createState() => _ThreePaneState();
}

class _ThreePaneState extends ConsumerState<_ThreePane> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedItemId;
  }

  void _handleSelect(ReminderItem item) {
    setState(() => _selectedId = item.id);
    widget.onSelectItem?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final openListId = widget.openListId;
    final lists = widget.lists;
    final current = lists.where((e) => e.id == openListId).firstOrNull;
    final itemsAsync = ref.watch(itemsForListProvider(openListId));
    final selected = itemsAsync.maybeWhen(
      data: (items) => items.where((e) => e.id == _selectedId).firstOrNull,
      orElse: () => null,
    );
    final sidebarVisible = ref.watch(sidebarVisibleProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebarWidth = ReminderTokens.sidebarWidth(constraints.maxWidth);
        return Row(
          key: const ValueKey('three_pane'),
          children: [
            if (sidebarVisible) ...[
              SizedBox(
                width: sidebarWidth,
                child: TaskSidebar(
                  lists: lists,
                  selectedListId: openListId,
                  onSelect: (l) => widget.onOpenList?.call(l.id),
                  onAddList: () => showNewListDialog(
                    context,
                    onCreate: (list) =>
                        ref.read(reminderRepositoryProvider).upsertList(list),
                  ),
                  onToggleSidebar: () =>
                      ref.read(sidebarVisibleProvider.notifier).toggle(),
                  onOpenSettings: () => openTaskSettings(
                    context,
                    ref,
                    onOpenCloudLogin: widget.onOpenCloudLogin,
                  ),
                ),
              ),
              const _VerticalHairline(),
            ],
            Expanded(
              child: current == null
                  ? _SharedOrEmptyPane(
                      openListId: openListId,
                      showSidebarButton: !sidebarVisible,
                      onShowSidebar: () =>
                          ref.read(sidebarVisibleProvider.notifier).set(true),
                    )
                  : ListContentPane(
                      list: current,
                      onSelectItem: _handleSelect,
                      selectedItem: selected,
                      listTitles: {for (final l in lists) l.id: l.title},
                      leading: sidebarVisible
                          ? null
                          : Semantics(
                              label: '显示侧栏',
                              button: true,
                              child: CupertinoButton(
                                key: const ValueKey('show_sidebar'),
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.all(6),
                                onPressed: () => ref
                                    .read(sidebarVisibleProvider.notifier)
                                    .set(true),
                                child: const Icon(
                                  CupertinoIcons.sidebar_left,
                                  size: 20,
                                ),
                              ),
                            ),
                    ),
            ),
            if (selected != null) ...[
              const _VerticalHairline(),
              SizedBox(
                width: 320,
                child: KeyedSubtree(
                  key: ValueKey('inspector_${selected.id}'),
                  child: ReminderDetailPane(
                    item: selected,
                    onSaved: (updated) => ref
                        .read(reminderRepositoryProvider)
                        .upsertItem(updated),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 主区在「不是本人清单」时的落点（#599 判据：选中态得能接受 shared id，
/// 别只画一行死字）：在我共享册里 ⇒ 只读视图；否则维持原空态。
class _SharedOrEmptyPane extends ConsumerWidget {
  const _SharedOrEmptyPane({
    required this.openListId,
    this.showSidebarButton = false,
    this.onShowSidebar,
  });

  final String? openListId;
  final bool showSidebarButton;
  final VoidCallback? onShowSidebar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shared = openListId == null
        ? null
        : ref.watch(sharedListByIdProvider(openListId!));
    if (shared == null) {
      return _EmptyOverview(
        showSidebarButton: showSidebarButton,
        onShowSidebar: onShowSidebar,
      );
    }
    return SharedListPane(
      key: ValueKey('shared_view_${shared.listId}'),
      list: shared,
      leading: showSidebarButton
          ? Semantics(
              label: '显示侧栏',
              button: true,
              child: CupertinoButton(
                key: const ValueKey('show_sidebar'),
                minimumSize: Size.zero,
                padding: const EdgeInsets.all(6),
                onPressed: onShowSidebar,
                child: const Icon(CupertinoIcons.sidebar_left, size: 20),
              ),
            )
          : null,
    );
  }
}

class _EmptyOverview extends StatelessWidget {
  const _EmptyOverview({this.showSidebarButton = false, this.onShowSidebar});

  final bool showSidebarButton;
  final VoidCallback? onShowSidebar;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(
        CupertinoColors.systemBackground,
        context,
      ),
      navigationBar: showSidebarButton
          ? CupertinoNavigationBar(
              automaticallyImplyLeading: false,
              leading: Semantics(
                label: '显示侧栏',
                button: true,
                child: CupertinoButton(
                  key: const ValueKey('show_sidebar'),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.all(6),
                  onPressed: onShowSidebar,
                  child: const Icon(CupertinoIcons.sidebar_left, size: 20),
                ),
              ),
            )
          : null,
      child: const Center(child: Text('选择一个列表')),
    );
  }
}

/// 列表内容区（布局无关）：条目行 + 完成态/旗标即时回写 + 新建提醒草稿行 +
/// 底部工具条（iOS 提醒事项式「＋ 新提醒」；智能视图隐藏）。
///
/// [leading] 供紧凑端壳内子路由显示「‹ 列表」返回；medium/expanded 二栏/三栏不传即可。
/// 「移至分区…」弹层里「不在分区」那一项的返回值。
///
/// 不能用空串以外的假 id：分区 id 由 `newSectionId()` 生成（`sec_` 前缀），
/// 这里取一个不可能撞上的常量，取消则返回 null，三者互不混淆。
const String _moveToSectionNone = 'section:none';

/// #537/#545 共用：今天视图的「时间档」白名单——只有这四档在 [_sectionTime]
/// 里定义了具体时刻，所以既能被拖入，也是「将截止日期标记为…」的全部选项。
///
/// 「已过期」不在其中：Apple 的 Mark 里没有「标成过期」这一档，而它本身也不是
/// 一个时刻；「未分区」与计划视图的日期/分组标题同理。非时间档一律不改 dueAt。
const List<String> _timeSectionBuckets = ['上午', '下午', '今晚', '今天'];

class ListContentPane extends ConsumerStatefulWidget {
  const ListContentPane({
    super.key,
    required this.list,
    this.onSelectItem,
    this.leading,
    this.listTitles,
    this.selectedItem,
  });

  final ReminderList list;
  final ValueChanged<ReminderItem>? onSelectItem;

  /// 紧凑端 AppBar 左侧返回（如「‹ 列表」）；null 时用系统默认（或无 leading）。
  final Widget? leading;

  /// 条目副标题用的真实列表名（智能视图下不是「今天/计划」）。
  final Map<String, String>? listTitles;

  /// #537：三栏（expanded）里当前选中的条目，「移至分区…」的操作对象。
  /// 选中态归 `_ThreePane`，这里只接过来用；两栏/紧凑栏没有选中面，传 null。
  final ReminderItem? selectedItem;

  @override
  ConsumerState<ListContentPane> createState() => _ListContentPaneState();
}

/// #585：此刻活着的清单页。壳的分支栈会同时挂着两张（见
/// `_answersListMenuActions`），选应答者要有这份在册名单；随 State 挂载/销毁增删。
final Set<_ListContentPaneState> _liveListPanes = <_ListContentPaneState>{};

class _ListContentPaneState extends ConsumerState<ListContentPane> {
  final _draftController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _showDraft = false;

  /// #513 面①：分区「＋」触发的草稿落点分区（null = 普通幽灵行新建）。
  String? _pendingQuickAddSection;

  /// #487 面②：计划视图组末空圆圈触发的草稿落点「那一天」（null = 走 [_sectionTime]）。
  DateTime? _pendingQuickAddDay;
  TaskShortcutsController? _shortcuts;
  int _lastNewTicket = 0;
  int _lastSearchTicket = 0;
  int _lastNewListTicket = 0;
  bool _newListDialogOpen = false;

  /// 菜单命令（#375）：菜单栏在 `CupertinoApp` 之上、拿不到页面 context，
  /// 只能靠这条总线通知；与 ⌘N 一样落到 [_openNewItemDialog]。
  ValueNotifier<LifeMenuAction?>? _menuCommands;

  @override
  void initState() {
    super.initState();
    // 延迟到首帧后取外层控制器（避免 build 期依赖）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = TaskShortcuts.of(context);
      _shortcuts = controller;
      _lastNewTicket = controller.newReminderTicket;
      _lastSearchTicket = controller.focusSearchTicket;
      _lastNewListTicket = controller.newListTicket;
      controller.addListener(_onShortcut);

      _menuCommands = ref.read(lifeMenuCommandsProvider);
      _menuCommands?.addListener(_onMenuCommand);
      // 菜单先发命令、页面后挂载（切 tab 的时序）时补消费一次。
      _onMenuCommand();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _paneRoute = ModalRoute.of(context);
    _liveListPanes.add(this);
  }

  /// #585：读写「当前这张清单」或当前选中行的动作。这类票据只许前台那张页消费，
  /// 否则身后那张还挂在分支栈上的 `/` 页会拿默认的「今天」去应答。
  /// 其余（显示、排序、视图模式、设置、新建列表）写的是全局视图态，谁消费都一样。
  static const Set<LifeMenuAction> _listScopedMenuActions = {
    LifeMenuAction.newSection,
    LifeMenuAction.editList,
    LifeMenuAction.editSections,
    LifeMenuAction.printList,
    LifeMenuAction.moveToSection,
    LifeMenuAction.deleteReminder,
    LifeMenuAction.replaceText,
    LifeMenuAction.markDueDate,
    LifeMenuAction.indentReminder,
    LifeMenuAction.outdentReminder,
    LifeMenuAction.createSectionFromSelection,
    LifeMenuAction.pinList,
    LifeMenuAction.unpinList,
  };

  /// 本页所属路由（壳的分支栈里一张页一条路由）。
  ModalRoute<Object?>? _paneRoute;

  /// #585：列表级动作只由「应答者」那张清单页消费。
  ///
  /// 壳的 `StatefulShellRoute` 分支栈会把 `/` 与 `/list/:listId` 两张页同时挂着，
  /// 于是同一时刻有两个 `ListContentPane` 监听同一张票据，而先注册的那张
  /// `widget.list` 还是默认的「今天」——它把票据吃掉就会误报「智能清单不用置顶」，
  /// 真正开着的那张清单收不到。
  ///
  /// 选应答者的规则（当场问路由，不缓存结论）：
  /// 1. 有页是当前路由 → 那张页应答；
  /// 2. 一张都不是（弹层压在头顶的那一刻，`isCurrent` 集体变 false）→ 由最后挂载
  ///    的那张应答，也就是用户眼前这张；命令不许被吞掉。
  bool get _answersListMenuActions {
    if (_paneRoute?.isCurrent ?? false) return true;
    final live = _liveListPanes;
    if (live.any((p) => p != this && (p._paneRoute?.isCurrent ?? false))) {
      return false;
    }
    return live.isEmpty || live.last == this;
  }

  /// 菜单栏命令消费（#486：扩展支持新建列表/设置/显示切换）。
  void _onMenuCommand() {
    final notifier = _menuCommands;
    if (notifier == null || !mounted) return;
    final action = notifier.value;
    if (action == null) return;
    // #585：列表级动作只由前台那张页消费。`StatefulShellRoute` 会把 `/` 与
    // `/list/:listId` 同时挂在分支栈上，同一时刻有两个 ListContentPane 监听
    // 同一张票据，而先注册的那个 `widget.list` 还是默认的「今天」——它吃掉票据
    // 就会误报「智能清单不用置顶」，真正开着的那张清单反而收不到。
    if (_listScopedMenuActions.contains(action) && !_answersListMenuActions) return;
    notifier.value = null; // 消费即清，避免重建时重复触发
    switch (action) {
      case LifeMenuAction.newReminder:
        _openNewItemDialog();
      case LifeMenuAction.newNote:
        // 备忘录命令由 note_scaffold 消费，task 侧不处理
        break;
      case LifeMenuAction.newList:
        _openNewListDialog();
      // #486：菜单的分区两项复用 #533 的入口与闸门（智能清单没有分区）。
      case LifeMenuAction.newSection:
        if (!widget.list.isSmart) _createSection();
      case LifeMenuAction.editList:
        if (!widget.list.isSmart) _editCurrentList();
      case LifeMenuAction.editSections:
        if (!widget.list.isSmart) _editSections();
      case LifeMenuAction.openSettings:
        _openSettings();
      case LifeMenuAction.toggleSmartLists:
        _toggleSmartLists();
      case LifeMenuAction.toggleSidebar:
        _toggleSidebar();
      case LifeMenuAction.toggleCompleted:
        _toggleShowCompleted();
      case LifeMenuAction.toggleGroupByTime:
        ref.read(groupByTimeProvider.notifier).toggle();
      case LifeMenuAction.viewModeList:
        ref.read(taskViewModeProvider.notifier).set(false);
      case LifeMenuAction.viewModeColumns:
        ref.read(taskViewModeProvider.notifier).set(true);
      // #602：分区列排（矩阵行 41）。与上一条 viewModeColumns 是两回事。
      case LifeMenuAction.toggleSectionColumns:
        ref.read(sectionColumnsProvider.notifier).toggle();
      case LifeMenuAction.printList:
        _printCurrentList();
      // #537：「显示 → 排序方式」五档，写的是工具栏同一个 listSortModeProvider，
      // 排序比较器一律复用 [_sortTopLevel]，菜单侧不实现第二套排序。
      case LifeMenuAction.sortByManual:
        _setSortFromMenu(ListSortMode.manual);
      case LifeMenuAction.sortByDueDate:
        _setSortFromMenu(ListSortMode.dueDate);
      case LifeMenuAction.sortByCreatedDate:
        _setSortFromMenu(ListSortMode.createdDate);
      case LifeMenuAction.sortByTitle:
        _setSortFromMenu(ListSortMode.title);
      case LifeMenuAction.sortByPriority:
        _setSortFromMenu(ListSortMode.priority);
      // #537：子任务显隐整体开关，读写都走 collapsedKeys 这条视图态通路。
      case LifeMenuAction.showAllSubtasks:
        ref.read(collapsedKeysProvider.notifier).setSubtasksHidden(false);
      case LifeMenuAction.hideSubtasks:
        ref.read(collapsedKeysProvider.notifier).setSubtasksHidden(true);
      // #537：「文件 → 移至分区…」。**不加 isSmart 闸门**：智能清单按定义
      // 不带分区，走下面的「还没有分区」提示才是可见结果；加闸门会变成点了没反应。
      case LifeMenuAction.moveToSection:
        _moveSelectedToSection();
      // #537：「编辑 → 删除提醒事项」。删除即软删进「最近删除」（TC-UI-109
      // 的 30 天回收窗），不弹二次确认——Apple 也是直接进回收站、当场可恢复。
      case LifeMenuAction.deleteReminder:
        _deleteSelectedReminder();
      // #537：「编辑 → 查找…」= 与 ⌘F 同一个入口。走 TaskShortcuts 的既有票据
      // （`_onShortcut` 比对 focusSearchTicket 后 requestFocus），不在这里碰焦点。
      case LifeMenuAction.findReminder:
        _shortcuts?.requestFocusSearch();
      case LifeMenuAction.replaceText:
        _replaceSelectedText();
      // #537：「编辑 → 将截止日期标记为…」。档位时刻与落库一律复用今天视图
      // 拖档那一份（`_sectionTime` + `_onSectionDrop`），不开第二条写日期通路。
      case LifeMenuAction.markDueDate:
        _markSelectedDueDate();
      // #537：「编辑 → 缩进 / 减少缩进」改的是 `parentId`，归属对象按
      // `_menuVisibleRows`（渲染处收一次的真实行序）取，不在这里重抄
      // 过滤/排序/折叠规则——重抄的那份迟早和界面不一致。
      case LifeMenuAction.indentReminder:
        _indentSelectedReminder();
      case LifeMenuAction.outdentReminder:
        _outdentSelectedReminder();
      // flutter #567：⌃⌘N「用所选项目新建分区」。与 ⋯ 菜单共用同一个实现承载，
      // 不开第二条写库通路；未选中由 `_createSectionFromSelection` 自己给提示。
      case LifeMenuAction.createSectionFromSelection:
        _createSectionFromSelection();
      // #537：「文件 → 置顶列表 / 取消置顶列表」，作用对象是前台列表。
      case LifeMenuAction.pinList:
        _setCurrentListPinned(true);
      case LifeMenuAction.unpinList:
        _setCurrentListPinned(false);
    }
  }

  void _setSortFromMenu(ListSortMode mode) {
    ref.read(listSortModeProvider.notifier).set(mode);
  }

  /// #572：「文件 → 打印…」——当前前台清单导出 PDF，交给系统打印面板。
  Future<void> _printCurrentList() async {
    final items = await ref.read(
      filteredItemsForListProvider(widget.list.id).future,
    );
    if (!mounted) return;
    if (items.isEmpty) {
      await _showMenuNotice('打印', '当前列表没有可打印的提醒');
      return;
    }
    try {
      final font = loadSystemCjkFont();
      final bytes = await buildTaskListPdf(
        listTitle: widget.list.title,
        items: items,
        font: font,
      );
      if (!mounted) return;
      await ref.read(taskPrintPortProvider)(bytes, widget.list.title);
    } catch (_) {
      if (!mounted) return;
      await _showMenuNotice('打印', '打印失败，请稍后重试');
    }
  }

  /// #576：「编辑 → 替换…」——只作用于当前选中条目（标题 + 备注），
  /// 精确子串替换；查找为空或没有命中都给可见提示，不写库。
  Future<void> _replaceSelectedText() async {
    final item = widget.selectedItem;
    if (item == null) {
      await _showMenuNotice('替换', '先选中一条提醒事项');
      return;
    }
    final findController = TextEditingController();
    final withController = TextEditingController();
    final apply = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => LifeAlertDialog(
        title: const Text('替换'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              key: const ValueKey('replace_find'),
              controller: findController,
              autofocus: true,
              placeholder: '查找',
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              key: const ValueKey('replace_with'),
              controller: withController,
              placeholder: '替换为',
            ),
          ],
        ),
        actions: [
          LifeDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          LifeDialogAction(
            key: const ValueKey('replace_submit'),
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('替换'),
          ),
        ],
      ),
    );
    if (apply != true || !mounted) return;
    final find = findController.text;
    if (find.isEmpty) {
      await _showMenuNotice('替换', '查找内容不能为空');
      return;
    }
    final replacement = withController.text;
    final newTitle = item.title.replaceAll(find, replacement);
    final newNotes = item.notes?.replaceAll(find, replacement);
    if (newTitle == item.title && newNotes == item.notes) {
      await _showMenuNotice('替换', '没有找到「$find」');
      return;
    }
    await ref.read(reminderRepositoryProvider).upsertItem(
          item.copyWith(title: newTitle, notes: newNotes),
        );
  }

  /// #537：把三栏里选中的条目移进某个分区（或移出分区）。
  ///
  /// 选择器用 `CupertinoActionSheet`，与「编辑列表」那面同一个形态；写回走
  /// [ReminderRepository.upsertItem] 全量回写（端口不设字段级 setter）。
  Future<void> _moveSelectedToSection() async {
    final item = widget.selectedItem;
    if (item == null) {
      await _showMenuNotice('移至分区', '先选中一条提醒事项');
      return;
    }
    final sections = widget.list.sections;
    if (sections.isEmpty) {
      await _showMenuNotice('移至分区', '这个列表还没有分区');
      return;
    }
    if (!mounted) return;
    final picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('移至分区'),
        message: Text(item.title),
        actions: [
          for (final s in sections)
            CupertinoActionSheetAction(
              key: ValueKey('move_to_section_${s.id}'),
              onPressed: () => Navigator.of(ctx).pop(s.id),
              child: Text(s.title),
            ),
          CupertinoActionSheetAction(
            key: const ValueKey('move_to_section_none'),
            onPressed: () => Navigator.of(ctx).pop(_moveToSectionNone),
            child: const Text('不在分区'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (picked == null) return;
    await ref
        .read(reminderRepositoryProvider)
        .upsertItem(
          item.copyWith(
            sectionId: picked == _moveToSectionNone ? null : picked,
          ),
        );
  }

  /// #537：删除三栏里选中的那条提醒（进「最近删除」，不是硬删）。
  ///
  /// 级联（父删子随）与回收窗一律复用 [ReminderRepository.deleteItem]
  /// 既有契约，菜单侧不实现第二套删除。
  Future<void> _deleteSelectedReminder() async {
    final item = widget.selectedItem;
    if (item == null) {
      await _showMenuNotice('删除提醒事项', '先选中一条提醒事项');
      return;
    }
    if (_isTrashView) {
      await _showMenuNotice('删除提醒事项', '这条已在最近删除里，可直接恢复');
      return;
    }
    await ref.read(reminderRepositoryProvider).deleteItem(item.id);
  }

  /// #537：把三栏里选中的那条标到某个日期档。
  ///
  /// 落库直接调 `_onSectionDrop`（今天视图拖档那一份），所以菜单里不会
  /// 出现第二套「今晚是几点」的定义，也不会绕开它的 `newDue != item.dueAt` 判定。
  Future<void> _markSelectedDueDate() async {
    final item = widget.selectedItem;
    if (item == null) {
      await _showMenuNotice('将截止日期标记为', '先选中一条提醒事项');
      return;
    }
    if (!mounted) return;
    final picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('将截止日期标记为'),
        message: Text(item.title),
        actions: [
          for (final bucket in _timeSectionBuckets)
            CupertinoActionSheetAction(
              key: ValueKey('mark_due_date_$bucket'),
              onPressed: () => Navigator.of(ctx).pop(bucket),
              child: Text(bucket),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (picked == null) return;
    await _onSectionDrop(item.id, picked);
  }

  /// #537/#563：「文件 → 置顶列表 / 取消置顶列表」写清单实体的 `isPinned`。
  ///
  /// 以前这行写的是视图态键袋（只作用于本机侧栏）；改成落库字段后置顶会随
  /// 同步通道走，换设备还在。智能清单直接拒绝（与排序侧的 `isSmart` 闸门同口径）。
  Future<void> _setCurrentListPinned(bool pinned) async {
    final list = widget.list;
    if (list.isSmart) {
      await _showMenuNotice('置顶列表', '智能清单不用置顶');
      return;
    }
    await ref
        .read(reminderRepositoryProvider)
        .upsertList(list.copyWith(isPinned: pinned));
  }

  /// #537：渲染处每轮刷新一次的「可见行序」（父行后紧跟其子行）。
  /// 只在 build 里赋值、不 setState——它是那一帧的派生物，不是新状态。
  List<ReminderItem> _menuVisibleRows = const [];

  /// flutter #567：多选态。Apple 的「用所选项目新建分区（⌃⌘N）」要求先选中若干条，
  /// 而本仓此前**只有单选**（`selectedItemId` / `_selectedId`），没有任何多选态
  /// （0 命中是用 `longPress|selectedIds|SelectMode|Checkbox` 在同一批目录量的，
  /// 正对照见 #567 正文）。长按一行进入选择态，之后再点行=勾选/取消勾选。
  bool _selecting = false;
  final Set<String> _selectedIds = <String>{};

  /// 勾选靶与长按入口都长在这条通路外，`!_selecting` 时树形与改动前逐字一致。
  Widget _wrapSelectable(ReminderItem item, Widget row) {
    return GestureDetector(
      key: ValueKey('row_long_press_${item.id}'),
      onLongPress: () => _toggleSelected(item.id),
      child: _selecting
          ? Row(
              children: [
                CupertinoButton(
                  key: ValueKey('select_${item.id}'),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () => _toggleSelected(item.id),
                  child: Icon(
                    _selectedIds.contains(item.id)
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    size: 20,
                    color: _selectedIds.contains(item.id)
                        ? ReminderTokens.systemBlue
                        : ReminderTokens.labelTertiary,
                  ),
                ),
                Expanded(child: row),
              ],
            )
          : row,
    );
  }

  void _toggleSelected(String id) {
    setState(() {
      _selecting = true;
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
      if (_selectedIds.isEmpty) _selecting = false;
    });
  }

  void _exitSelection() => setState(() {
    _selecting = false;
    _selectedIds.clear();
  });

  /// flutter #567：「用所选项目新建分区」的实现承载。
  ///
  /// 未选中 ⇒ 给可见提示并**返回**（不写任何数据）。这条分支同时服务两个入口：
  /// 列表 ⋯ 菜单（那条会把菜单项置灰）与 macOS 菜单栏（按 #537 定的不变量，
  /// 菜单侧不判选中，只投命令）。静默 no-op 等于菜单坏了。
  Future<void> _createSectionFromSelection() async {
    if (_selectedIds.isEmpty) {
      await _showMenuNotice('用所选项目新建分区', '先长按选中要归入分区的提醒');
      return;
    }
    final ids = _selectedIds.toList(growable: false);
    await showNewSectionDialog(
      context,
      list: widget.list,
      repository: ref.read(reminderRepositoryProvider),
      taskIds: ids,
    );
    if (mounted) _exitSelection();
  }

  /// #537：「编辑 → 缩进」= 把选中那条挂到它上面那一行之下。
  ///
  /// 三种不做的情况都给可见提示（静默 no-op 等于菜单坏了）：上面没有行、
  /// 已经挂在那儿了、它自己还带着子任务（挪父级会把整棵子树一起搬走，
  /// Apple 也是直接拒绝）。
  Future<void> _indentSelectedReminder() async {
    final item = widget.selectedItem;
    if (item == null) {
      await _showMenuNotice('缩进', '先选中一条提醒事项');
      return;
    }
    if (_isTrashView) {
      await _showMenuNotice('缩进', '最近删除里不能改层级');
      return;
    }
    final order = _menuVisibleRows;
    final index = order.indexWhere((e) => e.id == item.id);
    if (index <= 0) {
      await _showMenuNotice('缩进', '它上面没有可以归属的提醒事项');
      return;
    }
    final above = order[index - 1];
    if (above.id == item.parentId) {
      await _showMenuNotice('缩进', '这条已经挂在那个下面了');
      return;
    }
    if (order.any((e) => e.parentId == item.id)) {
      await _showMenuNotice('缩进', '这条自己还有子任务，先把子任务移走');
      return;
    }
    await ref
        .read(reminderRepositoryProvider)
        .upsertItem(item.copyWith(parentId: above.id));
  }

  /// #537：「编辑 → 减少缩进」= 升一层，父级换成祖父级（顶层条目没有可减的层）。
  Future<void> _outdentSelectedReminder() async {
    final item = widget.selectedItem;
    if (item == null) {
      await _showMenuNotice('减少缩进', '先选中一条提醒事项');
      return;
    }
    if (_isTrashView) {
      await _showMenuNotice('减少缩进', '最近删除里不能改层级');
      return;
    }
    final parentId = item.parentId;
    if (parentId == null) {
      await _showMenuNotice('减少缩进', '这条已经在最外层');
      return;
    }
    final parents = _menuVisibleRows.where((e) => e.id == parentId);
    final parent = parents.isEmpty ? null : parents.first;
    if (parent == null) {
      // 孤儿（父不在结果集）按顶层渲染，减无可减。
      await _showMenuNotice('减少缩进', '这条已经在最外层');
      return;
    }
    await ref
        .read(reminderRepositoryProvider)
        .upsertItem(item.copyWith(parentId: parent.parentId));
  }

  Future<void> _showMenuNotice(String title, String message) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => LifeAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          LifeDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  void _openNewListDialog() {
    _newListDialogOpen = true;
    showNewListDialog(
      context,
      onCreate: (list) => ref.read(reminderRepositoryProvider).upsertList(list),
    ).whenComplete(() => _newListDialogOpen = false);
  }

  Future<void> _openSettings() {
    // 菜单入口没有登录页上下文（与改造前一致的弱化文案）。
    return openTaskSettings(context, ref);
  }

  void _toggleSmartLists() {
    ref.read(smartListsVisibleProvider.notifier).toggle();
  }

  void _toggleSidebar() {
    ref
        .read(sidebarVisibleProvider.notifier)
        .set(!ref.read(sidebarVisibleProvider));
  }

  void _toggleShowCompleted() {
    final list = widget.list;
    final current = ref.read(showCompletedByListProvider)[list.id] ?? false;
    ref.read(showCompletedByListProvider.notifier).setFor(list.id, !current);
  }

  void _onShortcut() {
    final controller = _shortcuts;
    if (controller == null) return;
    if (controller.newReminderTicket != _lastNewTicket) {
      _lastNewTicket = controller.newReminderTicket;
      _openNewItemDialog();
    }
    if (controller.focusSearchTicket != _lastSearchTicket) {
      _lastSearchTicket = controller.focusSearchTicket;
      _searchFocus.requestFocus();
    }
    if (controller.newListTicket != _lastNewListTicket) {
      _lastNewListTicket = controller.newListTicket;
      // #249：⌘⇧N 与侧栏「新建列表」走同一条落库路径（TC-UI-316）。
      // 连按不叠弹层：已开着就忽略后续票据。
      if (!_newListDialogOpen) {
        _newListDialogOpen = true;
        showNewListDialog(
          context,
          onCreate: (list) =>
              ref.read(reminderRepositoryProvider).upsertList(list),
        ).whenComplete(() => _newListDialogOpen = false);
      }
    }
  }

  @override
  void dispose() {
    _liveListPanes.remove(this);
    _shortcuts?.removeListener(_onShortcut);
    _menuCommands?.removeListener(_onMenuCommand);
    _searchFocus.dispose();
    _draftController.dispose();
    super.dispose();
  }

  bool get _isSmartView => widget.list.id.startsWith('smart.');

  /// 最近删除视图（smart.trash）：恢复语义、无新建入口（TC-UI-109）。
  bool get _isTrashView => widget.list.id == 'smart.trash';

  /// 分区（线框「分区一 ∨」）：**手动分区优先**（列表带 sections 元数据时按
  /// sectionId 挂靠 + 未分区兜底；TC-KR-118 互斥契约——一列表一种分组模式）；
  /// 无分区元数据回退 dueAt 日桶，无日期单独一区。
  /// 保序：手动分区按元数据 sortOrder asc, id asc；日桶沿用 items 排序。
  _SectionLayout _buildSections(
    List<ReminderItem> topLevel, {
    bool searching = false,
  }) {
    final manual = widget.list.sections;
    if (manual.isNotEmpty) {
      final byId = {for (final s in manual) s.id: s};
      final sections = <String, List<ReminderItem>>{};
      // 元数据序建桶（空分区也显示头，Apple 同款）
      for (final s in manual) {
        sections.putIfAbsent(s.title, () => []);
      }
      for (final item in topLevel) {
        final sec = item.sectionId == null ? null : byId[item.sectionId];
        final key = sec?.title ?? '未分区';
        sections.putIfAbsent(key, () => []).add(item);
      }
      // 未分区（含孤儿 sectionId）恒排最后
      final ordered = <String, List<ReminderItem>>{};
      for (final s in manual) {
        ordered[s.title] = sections[s.title] ?? [];
      }
      if (sections.containsKey('未分区')) {
        ordered['未分区'] = sections['未分区']!;
      }
      return _SectionLayout(ordered, const {});
    }

    if (widget.list.id == 'smart.today') {
      final now = ref.read(clockProvider)();
      final today = DateTime(now.year, now.month, now.day);
      final buckets = <String, List<ReminderItem>>{
        '已过期': [],
        '今天': [],
        '上午': [],
        '下午': [],
        '今晚': [],
      };
      for (final item in topLevel) {
        final due = item.dueAt;
        if (due == null) {
          buckets['今天']!.add(item);
          continue;
        }
        final allDay = due.hour == 0 && due.minute == 0;
        // #474：全天项只按日期判过期（当天 00:00 不算已过）；
        // #484：定时项按时刻判——今天更早的提醒也要进「已过期」段（Apple 同款）。
        final overdue = allDay
            ? DateTime(due.year, due.month, due.day).isBefore(today)
            : due.isBefore(now);
        if (overdue) {
          buckets['已过期']!.add(item);
        } else if (allDay) {
          buckets['今天']!.add(item);
        } else if (due.hour < 12) {
          buckets['上午']!.add(item);
        } else if (due.hour < 18) {
          buckets['下午']!.add(item);
        } else {
          buckets['今晚']!.add(item);
        }
      }
      return _SectionLayout({
        for (final key in buckets.keys)
          if (buckets[key]!.isNotEmpty) key: buckets[key]!,
      }, const {});
    }

    // #478：「全部」默认按提醒事项列表分组（guide/mac/zh-cn/14:25），
    // 与「计划」的按日期分组（同段 14:24）是两种模式，别混用日期桶。
    // #574：「显示 → 根据时间分组」打开时改走下面的日期分组（与计划同一套标签/排序）。
    if (widget.list.id == 'smart.all' && !ref.read(groupByTimeProvider)) {
      return _SectionLayout(_sectionsByReminderList(topLevel), const {});
    }

    final now = ref.read(clockProvider)();
    final sections = <String, List<ReminderItem>>{};
    for (final item in topLevel) {
      final key = item.dueAt == null ? '无日期' : _sectionLabel(item.dueAt!, now);
      sections.putIfAbsent(key, () => []).add(item);
    }
    // #475：计划/紧急视图按日期升序排分区（Apple 口径：已过期→今天→明天→日期升序）。
    // 此前组序 = 条目首现序，导致「已过期」排最后、跨月日期乱序。
    if (widget.list.id == 'smart.scheduled' ||
        widget.list.id == 'smart.urgent' ||
        widget.list.id == 'smart.all') {
      final sorted = _sortSectionsByDate(sections);
      // #487：计划视图补未来月份空骨架（Apple 逐月铺到年底）
      // #531：搜索态例外——Apple 搜索时只出匹配结果，不铺空骨架，
      // 否则 4 条命中会被十几屏空月头淹没。
      if (widget.list.id == 'smart.scheduled' && !searching) {
        final laid = _addFutureSkeletons(sorted, now);
        return _SectionLayout(
          laid.sections,
          _daySections(laid.sections, laid.daySkeletons),
        );
      }
      // 搜索态（#531）与紧急视图：组末快捷行只服务于「计划」的空骨架档位。
      return _SectionLayout(sorted, const {});
    }
    return _SectionLayout(sections, const {});
  }

  /// #487 面②：把「能定位到具体一天」的组挑出来 —— 条目组取组内最早 dueAt 那天，
  /// 逐日骨架组取 [_addFutureSkeletons] 记下的日子。
  ///
  /// 挑不出的组**故意不进这张表**，因此也就拿不到组末快捷行：
  /// 「已过期」（#513 面② 已定口径：不提供新建入口）、「无日期」、
  /// 以及月档（「十一月其他时间」「十二月」「2027年一月」——Apple 的月桶只有头，
  /// 一条空圆圈对不上「哪一天」）。
  Map<String, DateTime> _daySections(
    Map<String, List<ReminderItem>> sections,
    Map<String, DateTime> daySkeletons,
  ) {
    final out = <String, DateTime>{};
    for (final entry in sections.entries) {
      if (entry.key == '已过期' || entry.key == '无日期') continue;
      DateTime? best;
      for (final item in entry.value) {
        final due = item.dueAt;
        if (due == null) continue;
        final day = DateTime(due.year, due.month, due.day);
        if (best == null || day.isBefore(best)) best = day;
      }
      final day = best ?? daySkeletons[entry.key];
      if (day != null) out[entry.key] = day;
    }
    return out;
  }

  /// #487：为计划视图补未来骨架；#527 定档为 Apple 实测的三档：
  /// ① 本周内逐日（周日为一周之末）；② 本月剩余 → 单个「X月其他时间」桶；
  /// ③ 之后逐月，跨年带年份（`十二月` / `2027年一月`），铺到明年年底。
  ///
  /// #526：组键必须走 [_sectionLabel]。#487 原来自己拼 `M月d日`，
  /// 与条目组的写法永不相等——相对词那天（「明天」）会多出一个空的「11月1日」，
  /// 带星期后缀那天（「11月3日 周二」）也会多出一个空的「11月3日」，
  /// 同一天出现两个组头。骨架与条目组同键这条不变量在本档继续成立。
  ({
    Map<String, List<ReminderItem>> sections,
    Map<String, DateTime> daySkeletons,
  })
  _addFutureSkeletons(Map<String, List<ReminderItem>> sections, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final monthEnd = DateTime(today.year, today.month + 1, 0);
    // weekday 周一=1…周日=7 ⇒ 今天到本周日的日历日差 = 7 - weekday。
    final weekEnd = DateTime(
      today.year,
      today.month,
      today.day + (7 - today.weekday),
    );

    // 空骨架组没有 dueAt，排序时要按「它代表哪天」落位。
    final skeletonDays = <String, DateTime>{};
    final skeleton = <String, List<ReminderItem>>{};
    // #487 面②：只有**逐日档**的骨架组能定位到具体一天，月档（下面两档）不能——
    // 组末空圆圈只铺到前者，月桶按 Apple 只有组头。
    final daySkeletons = <String, DateTime>{};
    void putSkeleton(String key, DateTime repDay) {
      skeletonDays[key] = repDay;
      skeleton.putIfAbsent(key, () => const <ReminderItem>[]);
    }

    for (
      var day = DateTime(today.year, today.month, today.day + 1);
      !day.isAfter(weekEnd);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      final key = _sectionLabel(day, now);
      putSkeleton(key, day);
      daySkeletons[key] = day;
    }
    if (weekEnd.isBefore(monthEnd)) {
      // 本月剩余只铺一个桶；代表日 = 逐日档之后的第一天，保证桶排在逐日之后。
      putSkeleton(
        '${_monthLabelZh(monthEnd)}其他时间',
        DateTime(weekEnd.year, weekEnd.month, weekEnd.day + 1),
      );
    }
    final lastMonth = DateTime(now.year + 1, 12, 1);
    for (
      var month = DateTime(today.year, today.month + 1, 1);
      !month.isAfter(lastMonth);
      month = DateTime(month.year, month.month + 1, 1)
    ) {
      // 本周跨进下个月时（如 11月30 那周），逐日头已占到月内前几天，
      // 该月桶要排在它们之后，否则会出现「十二月」压在「12月3日 周四」前面。
      final spilledIntoMonth =
          month.year == weekEnd.year && month.month == weekEnd.month;
      putSkeleton(
        _monthBucketLabel(month, now),
        spilledIntoMonth
            ? DateTime(weekEnd.year, weekEnd.month, weekEnd.day + 1)
            : month,
      );
    }

    final merged = Map<String, List<ReminderItem>>.from(sections);
    for (final entry in skeleton.entries) {
      merged.putIfAbsent(entry.key, () => entry.value);
    }
    DateTime? repDay(MapEntry<String, List<ReminderItem>> entry) {
      final fixed = skeletonDays[entry.key];
      if (fixed != null) return fixed;
      DateTime? best;
      for (final item in entry.value) {
        final due = item.dueAt;
        if (due == null) continue;
        final day = DateTime(due.year, due.month, due.day);
        if (best == null || day.isBefore(best)) best = day;
      }
      return best;
    }

    final entries = merged.entries.toList();
    entries.sort((a, b) {
      final da = repDay(a);
      final db = repDay(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      final byDay = da.compareTo(db);
      // 同日撞车（条目组与「X月其他时间」桶代表日相同）时条目组在前，
      // List.sort 不稳定，必须有这个确定性次键，否则渲染序随运行变。
      if (byDay != 0) return byDay;
      return a.value.isEmpty ? 1 : (b.value.isEmpty ? -1 : 0);
    });
    return (
      sections: {for (final entry in entries) entry.key: entry.value},
      daySkeletons: daySkeletons,
    );
  }

  /// #478：按所属提醒事项列表建组，组序跟边栏清单序（`listTitles` 按清单迭代序构造）。
  /// 分区键即组头文案（`LifeSectionHeader` 与折叠键都按标题走），因此同名清单会并组——
  /// 这是本仓分区契约的既有限制，不在本卡扩大。
  Map<String, List<ReminderItem>> _sectionsByReminderList(
    List<ReminderItem> items,
  ) {
    final titles = widget.listTitles ?? const <String, String>{};
    final grouped = <String, List<ReminderItem>>{};
    for (final item in items) {
      grouped
          .putIfAbsent(titles[item.listId] ?? item.listId, () => [])
          .add(item);
    }
    final ordered = <String, List<ReminderItem>>{};
    for (final title in titles.values) {
      if (grouped.containsKey(title)) ordered[title] = grouped[title]!;
    }
    for (final entry in grouped.entries) {
      ordered.putIfAbsent(entry.key, () => entry.value);
    }
    return ordered;
  }

  /// #475：把分区按日期升序重排；#479 后标签含相对词与星期后缀，
  /// 不再解析标签文本，改按「分区内最早 dueAt 日」排序。
  /// 已过期(≤D-3) → 前天 → 昨天 → 今天 → 明天 → 后天 → 绝对日期升序 → 无日期（最后）。
  Map<String, List<ReminderItem>> _sortSectionsByDate(
    Map<String, List<ReminderItem>> sections,
  ) {
    DateTime? earliestDay(List<ReminderItem> items) {
      DateTime? best;
      for (final it in items) {
        final d = it.dueAt;
        if (d == null) continue;
        final day = DateTime(d.year, d.month, d.day);
        if (best == null || day.isBefore(best)) best = day;
      }
      return best;
    }

    final entries = sections.entries.toList();
    entries.sort((a, b) {
      final da = earliestDay(a.value);
      final db = earliestDay(b.value);
      // 无日期组（scheduled/urgent 过滤后不会出现）恒最后。
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return {for (final e in entries) e.key: e.value};
  }

  /// #479：按日粒度的分区标签（Apple 形态）——近邻日相对词
  /// 前天(D-2)/昨天(D-1)/今天/明天(D+1)/后天(D+2)，更远日期带星期后缀
  /// （`11月2日 周一`）；D-3 及更早维持「已过期」聚合（#475 语义不变）。
  /// 日差用 UTC 午夜对午夜：#500——本地 `Duration(days: 1)` 按绝对时长
  /// 推进，DST 回拨日（25 小时）会落回同一天，导致「明天」整天不显示。
  static String _sectionLabel(DateTime due, DateTime now) {
    final diff = DateTime.utc(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    return switch (diff) {
      <= -3 => '已过期',
      -2 => '前天',
      -1 => '昨天',
      0 => '今天',
      1 => '明天',
      2 => '后天',
      _ => '${due.month}月${due.day}日 ${_weekdayZh[due.weekday - 1]}',
    };
  }

  static const _weekdayZh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  /// #527：骨架的月桶名用中文月序（Apple 实机为「十一月其他时间」「十二月」「2027年一月」），
  /// 与日粒度标签的 `M月d日` 阿拉伯数字形态刻意不同——两套档位，两种写法。
  static const _monthZh = [
    '一月',
    '二月',
    '三月',
    '四月',
    '五月',
    '六月',
    '七月',
    '八月',
    '九月',
    '十月',
    '十一月',
    '十二月',
  ];

  static String _monthLabelZh(DateTime day) => _monthZh[day.month - 1];

  /// #527：当年月桶不带年份，跨年带（`2027年一月`）。
  static String _monthBucketLabel(DateTime month, DateTime now) =>
      month.year == now.year
      ? _monthLabelZh(month)
      : '${month.year}年${_monthLabelZh(month)}';

  void _toggleSection(String key) {
    ref.read(collapsedKeysProvider.notifier).toggle(_collapsedKey(key));
  }

  /// #480/#513：分区 → 代表时刻的共用查表（拖放改时间与快捷新建同源）。
  DateTime _sectionTime(String sectionKey, DateTime today) {
    return switch (sectionKey) {
      '上午' => DateTime(today.year, today.month, today.day, 9),
      '下午' => DateTime(today.year, today.month, today.day, 15),
      '今晚' => DateTime(today.year, today.month, today.day, 20),
      '今天' => today,
      _ => today,
    };
  }

  /// #480/#513 面①：今天视图分区头「＋」→ 开启该分区的草稿输入态。
  /// #487 面②：计划视图组末空圆圈走同一条草稿通道，但带 `day`——
  /// 落库时刻由那一天的 00:00 决定，而不是 [_sectionTime] 的今天档。
  /// 落库在用户输入标题并回车后发生（空标题不落库，失焦即丢弃）。
  void _quickAddToSection(String sectionKey, {DateTime? day}) {
    setState(() {
      _pendingQuickAddSection = sectionKey;
      _pendingQuickAddDay = day;
      _showDraft = true;
      _draftController.clear();
    });
  }

  /// #513 面②：「已过期」档不提供新建入口。
  bool _canQuickAddToSection(String sectionKey) {
    return sectionKey != '已过期';
  }

  /// #477：今天视图拖入分区 → 更新条目 dueAt 到该分区的代表性时刻。
  /// 上午=09:00 下午=15:00 今晚=20:00 今天=全天(00:00) 已过期=不变。
  ///
  /// #545：「已过期=不变」以前只是注释——非时间档在 [_sectionTime] 里落
  /// `_ => today`，实测拖一次就把今晚 20:00 改成今天 00:00。现在按
  /// [_timeSectionBuckets] 卡住：档名不对应时刻就不写库，菜单与拖放共用同一份白名单。
  Future<void> _onSectionDrop(String itemId, String sectionKey) async {
    if (!_timeSectionBuckets.contains(sectionKey)) return;
    final repo = ref.read(reminderRepositoryProvider);
    final all = await repo.watchItems().first;
    final item = all.firstWhere((e) => e.id == itemId);
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final newDue = _sectionTime(sectionKey, today);
    if (newDue != item.dueAt) {
      await repo.upsertItem(item.copyWith(dueAt: newDue));
    }
  }

  /// 折叠态落在本地偏好行里（TC-UI-309，flutter#124 卡 4b）：
  /// 键带列表前缀，切列表/重开后各列表的折叠互不串味。
  String _collapsedKey(String title) => '${widget.list.id}|$title';

  bool _isCollapsed(Set<String> keys, String title) =>
      keys.contains(_collapsedKey(title));

  /// 列表内排序（TC-UI-111）：manual=仓库契约序；其余视图序即时生效、
  /// 不写回 sortOrder（线框「排序 ▾」语义）。
  List<ReminderItem> _sortTopLevel(List<ReminderItem> items) {
    final mode = ref.read(listSortModeProvider);
    final sorted = [...items];
    switch (mode) {
      case ListSortMode.manual:
        return items;
      case ListSortMode.dueDate:
        sorted.sort(
          (a, b) => (a.dueAt ?? DateTime(2999, 1, 1)).compareTo(
            b.dueAt ?? DateTime(2999, 1, 1),
          ),
        );
      case ListSortMode.createdDate:
        // Apple 默认「最新的排最前」；存量行没创建时间（null）排最后，不瞎猜顺序。
        sorted.sort((a, b) {
          final x = a.createdAt, y = b.createdAt;
          if (x == null && y == null) return 0;
          if (x == null) return 1;
          if (y == null) return -1;
          return y.compareTo(x);
        });
      case ListSortMode.title:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case ListSortMode.priority:
        sorted.sort((a, b) => b.priority.compareTo(a.priority));
    }
    return sorted;
  }

  /// 清除已完成（线框图2「N 项完成 · 清除」）：删除当前列表全部已完成顶层条目。
  /// Apple 口径：完成的提醒整条移除（deleteItem 级联其子任务）——cursor PR#11 意见3 拍板。
  Future<void> _clearCompleted(List<String> ids) async {
    final repo = ref.read(reminderRepositoryProvider);
    for (final id in ids) {
      await repo.deleteItem(id);
    }
  }

  /// #602：分区列排（矩阵行 41，Apple View ▸ Columns）。
  ///
  /// 只吃 `_buildSections` 已经算好的 map：键=列头、值=列内条目，
  /// 行组件一律复用 `_buildItemRow`，**不实现第二套行**（仓规：一列表一种分组模式）。
  /// 列宽固定 280，横向滚动；`compact` 档由调用侧不启用（见 providers 注释与 PR 说明）。
  Widget _sectionColumnsView(
    Map<String, List<ReminderItem>> sections,
    Map<String, List<ReminderItem>> subtasksByParent,
  ) {
    final keys = sections.keys.toList(growable: false);
    return SizedBox(
      key: const ValueKey('section_columns'),
      height: 360,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: keys.length,
        itemBuilder: (context, i) {
          final key = keys[i];
          final items = sections[key] ?? const <ReminderItem>[];
          return SizedBox(
            key: ValueKey('section_column_$key'),
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LifeSectionHeader(
                  key: ValueKey('section_header_$key'),
                  title: key,
                  count: items.length,
                  collapsed: false,
                  onToggle: () {},
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final item in items)
                        _buildItemRow(item, subtasksByParent: subtasksByParent),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemRow(
    ReminderItem item, {
    Map<String, List<ReminderItem>> subtasksByParent = const {},
  }) {
    final repo = ref.read(reminderRepositoryProvider);
    final listName = widget.listTitles?[item.listId] ?? widget.list.title;
    // #537：「隐藏所有子任务」只是不渲染子行。子任务仍带 parentId，
    // 因此不会被 `_sortTopLevel` 当孤儿提升到顶层；数据一律不动。
    final hideSubs = ref
        .watch(collapsedKeysProvider)
        .contains(subtasksHiddenKey);
    final subs = hideSubs
        ? const <ReminderItem>[]
        : (subtasksByParent[item.id] ?? const <ReminderItem>[]);
    // parity#166：进度取全量流（智能视图会把子任务过滤掉，不能只看本列表）
    final progress = ref.watch(subtaskProgressProvider).value?[item.id];
    final row = ReminderRow(
      item: item,
      now: ref.read(clockProvider)(),
      allDayAsOverdue:
          ref.watch(taskPreferenceProvider).value?.allDayRemindersOverdue ??
          false,
      listName: listName,
      subtaskDone: progress?.done ?? 0,
      subtaskTotal: progress?.total ?? 0,
      onToggleCompleted: () => completeReminder(ref, item),
      onToggleFlagged: () => repo.toggleFlagged(item.id),
      // flutter #567：选择态里点行=勾选/取消，不再改三栏的选中项。
      onTap: () => _selecting
          ? _toggleSelected(item.id)
          : widget.onSelectItem?.call(item),
      onDelete: _isTrashView ? null : () => repo.deleteItem(item.id),
    );
    // 最近删除视图：行尾「恢复」（TC-UI-109；对齐 Apple Recently Deleted）
    final trashRow = _isTrashView
        ? Row(
            children: [
              Expanded(child: row),
              CupertinoButton(
                key: ValueKey('restore_${item.id}'),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: () => repo.restoreItem(item.id),
                child: const Text(
                  '恢复',
                  style: TextStyle(color: ReminderTokens.systemBlue),
                ),
              ),
            ],
          )
        : row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _wrapSelectable(item, trashRow),
        for (final sub in subs)
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: ReminderRow(
              item: sub,
              now: ref.read(clockProvider)(),
              allDayAsOverdue:
                  ref
                      .watch(taskPreferenceProvider)
                      .value
                      ?.allDayRemindersOverdue ??
                  false,
              listName: listName,
              dense: true,
              // #537：子行也要能选中。不接这条，「减少缩进」在界面上永远点不到
              // （选中态只有顶层行能拿），而 Apple 的子任务是可点选的。
              onTap: () => widget.onSelectItem?.call(sub),
              onToggleCompleted: () => completeReminder(ref, sub),
              onToggleFlagged: () => repo.toggleFlagged(sub.id),
              onDelete: _isTrashView ? null : () => repo.deleteItem(sub.id),
            ),
          ),
      ],
    );
  }

  /// 防重入：Return 与「失焦提交」（#367）可能在同一帧内先后触发，
  /// 不加锁会落两条同名条目。
  bool _submittingDraft = false;

  Future<void> _submitDraft() async {
    if (_submittingDraft) return;
    final title = _draftController.text.trim();
    if (title.isEmpty) {
      // 空草稿失焦：直接收起，不落库（Apple：空行点到别处即消失）
      _pendingQuickAddSection = null;
      _pendingQuickAddDay = null;
      if (_showDraft && mounted) setState(() => _showDraft = false);
      return;
    }
    _submittingDraft = true;
    final repo = ref.read(reminderRepositoryProvider);
    // #513 面①：若来自分区「＋」，dueAt 用该分区的代表时刻
    // #487 面②：若来自计划视图的组末空圆圈，dueAt 直接用那一天的 00:00
    final pendingSection = _pendingQuickAddSection;
    final pendingDay = _pendingQuickAddDay;
    // 挂钟统一走 clockProvider：生产与测试注入同一口径；直接 DateTime.now()
    // 会让注入固定时钟的用例落错天（#487 组末快捷行的回归就栽在这里）。
    final now = ref.read(clockProvider)();
    final dueAtOverride =
        pendingDay ??
        (pendingSection != null ? _sectionTime(pendingSection, now) : null);
    // 智能视图内新建：必须落到对应视图的语义上——
    // today/scheduled/urgent 需要 dueAt 才能命中（smart.today 过滤 = !completed && 同日）；
    // 没有 dueAt 的条目只会出现在「全部」视图，在「今天」里不可见。
    await repo.upsertItem(
      ReminderItem(
        id: newReminderId(),
        listId: _isSmartView
            ? resolveSmartCreateListId(
                lists:
                    (ref.read(reminderListsProvider).value ??
                    const <ReminderList>[]),
                preferredId: ref
                    .read(taskPreferenceProvider)
                    .value
                    ?.defaultListId,
              )
            : widget.list.id,
        title: title,
        // 从「今天」/「计划」视图新建 → dueAt = 今天（只有日期，00:00）；
        // Apple 快速新建不带时刻，写 now 会让它一分钟后变「已过期→紧急」（#183）。
        // 从「全部/旗标/已完成」视图新建 → 不设 dueAt（归入个人列表，全部视图可见）
        dueAt:
            dueAtOverride ??
            ((widget.list.id == 'smart.today' ||
                    widget.list.id == 'smart.scheduled')
                ? DateTime(now.year, now.month, now.day)
                : null),
      ),
    );
    _draftController.clear();
    // 快捷新建的落点是一次性的：不清的话，下一次普通新建会静默继承
    // 上一次那个分区/那一天（#487 引入组末圆圈后这条通道有两个来源，必须收口）。
    _pendingQuickAddSection = null;
    _pendingQuickAddDay = null;
    if (mounted) setState(() => _showDraft = false);
    _submittingDraft = false;
  }

  Future<void> _openNewItemDialog() async {
    // 智能视图的落点在 [_submitDraft] 里按「默认列表 → 首个自有列表」解析
    // （#245；Apple：智能列表里新建落到设置的 Default List）。
    setState(() => _showDraft = true);
  }

  /// #533：分区生产入口——替掉原「按分区整理（规划）」置灰占位。
  Future<void> _createSection() => showNewSectionDialog(
    context,
    list: widget.list,
    repository: ref.read(reminderRepositoryProvider),
  );

  /// #537：菜单「文件 → 编辑列表」——编辑当前打开的那个清单，
  /// 与侧栏 ⋯ 走同一个 showEditListDialog（改名/颜色/类型）。
  Future<void> _editCurrentList() => showEditListDialog(
    context,
    list: widget.list,
    onSave: (updated) =>
        ref.read(reminderRepositoryProvider).upsertList(updated),
  );

  /// flutter#570：清单共享入口。
  ///
  /// 端口未注入（未登录/离线档）时给**说明**，不做置灰占位——
  /// 占位会让人以为功能已存在（#533 删掉的就是那种坏状态）。
  Future<void> _shareCurrentList() async {
    final port = ref.read(taskCollabPortProvider);
    if (port == null) {
      _showMenuNotice('共享清单', '当前环境未接入共享服务（未登录或离线档）。');
      return;
    }
    await showListShareSheet(context, list: widget.list, port: port);
  }

  Future<void> _editSections() => showSectionEditorSheet(
    context,
    list: widget.list,
    repository: ref.read(reminderRepositoryProvider),
  );

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(filteredItemsForListProvider(widget.list.id));
    // 计数用未过滤流（已完成默认隐藏后，头部仍要能报「N 项完成」）
    final allItemsAsync = ref.watch(itemsForListProvider(widget.list.id));
    final query = ref.watch(searchQueryProvider);
    // 排序态驱动列表体重建（TC-UI-111：切换即时生效）
    ref.watch(listSortModeProvider);
    final isPane = WindowSizeClass.fromWidth(
      MediaQuery.of(context).size.width,
    ).isPaneLayout;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(
        CupertinoColors.systemBackground,
        context,
      ),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoDynamicColor.resolve(
          CupertinoColors.systemBackground,
          context,
        ),
        // 桌面三栏不显示返回箭头（参考图主区直接是标题/工具条）。
        automaticallyImplyLeading: !isPane && widget.leading == null,
        leading: widget.leading,
        // macOS 大标题口径（图2）：宽屏不放标题，标题进内容区（列表色大字）
        middle: isPane ? null : Text(widget.list.title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPane)
              SizedBox(
                width: 220,
                child: CupertinoTextField(
                  key: const ValueKey('toolbar_search'),
                  focusNode: _searchFocus,
                  onChanged: (v) =>
                      ref.read(searchQueryProvider.notifier).set(v),
                  placeholder: '搜索',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      CupertinoIcons.search,
                      size: 16,
                      color: ReminderTokens.labelSecondary,
                    ),
                  ),
                  // parity#196：暗色档搜索框不能用写死白底，跟 #157 的
                  // 动态令牌一起走 systemBackground / separator。
                  style: const TextStyle(fontSize: 13),
                  decoration: BoxDecoration(
                    color: CupertinoDynamicColor.resolve(
                      CupertinoColors.systemBackground,
                      context,
                    ),
                    borderRadius: BorderRadius.circular(LifeRadius.md),
                    border: Border.all(
                      width: 0.5,
                      color: CupertinoDynamicColor.resolve(
                        CupertinoColors.separator,
                        context,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 6,
                  ),
                ),
              ),
            // 顶栏 ＋（图2 工具行；与 ⌘N 同构→草稿行）
            if (isPane)
              Semantics(
                label: '新提醒（⌘N）',
                button: true,
                child: CupertinoButton(
                  key: const ValueKey('toolbar_new_item'),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.all(6),
                  onPressed: _openNewItemDialog,
                  child: const Icon(CupertinoIcons.add),
                ),
              ),
            _MoreMenu(
              onToggleCompleted: () {
                final Map<String, bool> perList = ref.read(
                  showCompletedByListProvider,
                );
                final bool cur = perList[widget.list.id] ?? false;
                ref
                    .read(showCompletedByListProvider.notifier)
                    .setFor(widget.list.id, !cur);
              },
              showCompleted:
                  ref.watch(showCompletedByListProvider)[widget.list.id] ??
                  false,
              sectionsEnabled: !widget.list.isSmart,
              onNewSection: _createSection,
              onEditSections: _editSections,
              // flutter #567：选择态非空才给这条入口可点（value=null 即置灰）。
              selectionCount: _selectedIds.length,
              selecting: _selecting,
              onCreateFromSelection: _createSectionFromSelection,
              onExitSelection: _exitSelection,
              shareEnabled: !widget.list.isSmart,
              onShareList: _shareCurrentList,
            ),
          ],
        ),
      ),
      child: Column(
        children: [
          // #485：紧凑档列表视图也要能搜索（Apple 每个列表顶部都有搜索字段）。
          // 宽屏走工具栏 toolbar_search，这里补紧凑档入口，共用 searchQueryProvider。
          if (!isPane && !_isTrashView)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: CupertinoTextField(
                key: const ValueKey('compact_search'),
                // #537：与宽屏 toolbar_search 共用同一个焦点节点。两处渲染互斥
                // （isPane 二选一），一个节点不会同时挂在两个控件上；这样
                // 「编辑 → 查找…」在任何档宽都能聚焦到看得见的搜索框。
                focusNode: _searchFocus,
                onChanged: (v) => ref.read(searchQueryProvider.notifier).set(v),
                placeholder: '搜索',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    CupertinoIcons.search,
                    size: 16,
                    color: ReminderTokens.labelSecondary,
                  ),
                ),
                style: const TextStyle(fontSize: 15),
                decoration: BoxDecoration(
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.systemBackground,
                    context,
                  ),
                  borderRadius: BorderRadius.circular(LifeRadius.md),
                  border: Border.all(
                    width: 0.5,
                    color: CupertinoDynamicColor.resolve(
                      CupertinoColors.separator,
                      context,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (items) {
                final isSearchEmpty = query.trim().isNotEmpty && items.isEmpty;
                final isListEmpty =
                    items.isEmpty &&
                    !_isTrashView &&
                    !isSearchEmpty &&
                    !_showDraft;
                if (isSearchEmpty) {
                  return const Center(
                    key: Key('search_empty'),
                    child: Text('无匹配结果'),
                  );
                }
                // 顶层与子任务分组（watchItems 返回全层级；孤儿/环按顶层兜底）
                final itemsById = {for (final e in items) e.id: e};
                final topLevel = _sortTopLevel(
                  items
                      .where((e) {
                        if (e.parentId == null) return true;
                        // 孤儿（父不在结果集）或自环 → 按顶层渲染
                        return !itemsById.containsKey(e.parentId) ||
                            e.parentId == e.id;
                      })
                      .toList(growable: false),
                );
                final subtasksByParent = <String, List<ReminderItem>>{};
                for (final e in items) {
                  if (e.parentId != null &&
                      itemsById.containsKey(e.parentId) &&
                      e.parentId != e.id) {
                    subtasksByParent.putIfAbsent(e.parentId!, () => []).add(e);
                  }
                }

                // 头部计数走未过滤流（已完成可能被视图偏好隐藏）
                final all =
                    allItemsAsync.asData?.value ?? const <ReminderItem>[];
                final doneCount = all
                    .where((e) => e.isCompleted && e.parentId == null)
                    .length;
                final remainingCount = all
                    .where((e) => !e.isCompleted && e.parentId == null)
                    .length;

                // 分区（线框客户端「分区一 ∨」）：带 dueAt 的顶层条目按日桶折叠；
                // 无日期条目单独一区。折叠为内存态（P1 不持久化）。
                // smart.today/smart.scheduled 视图：分区头与列表标题重复 → 跳过
                final skipSectionHeader =
                    widget.list.id == 'smart.today' ||
                    widget.list.id == 'smart.scheduled';
                final layout = _buildSections(
                  topLevel,
                  searching: query.trim().isNotEmpty,
                );
                final sections = layout.sections;
                // #537：把「屏幕上真实会出现的行」按顺序留一份，给缩进/减少缩进
                // 当依据。父行紧跟它的子行，与 `_buildItemRow` 的渲染顺序一致。
                final subsHidden = ref
                    .read(collapsedKeysProvider)
                    .contains(subtasksHiddenKey);
                _menuVisibleRows = [
                  for (final entry in sections.entries)
                    if (!_isCollapsed(
                      ref.read(collapsedKeysProvider),
                      entry.key,
                    ))
                      for (final row in entry.value) ...[
                        row,
                        // 「隐藏所有子任务」时子行不渲染，行序里也不该有它们
                        if (!subsHidden)
                          for (final sub
                              in (subtasksByParent[row.id] ??
                                  const <ReminderItem>[]))
                            sub,
                      ],
                ];
                // #388：草稿行要有自己的可定位身份——工具栏搜索框同为
                // CupertinoTextField，按类型断言会连它一起数到，判据恒真。
                final draftRow = _DraftRow(
                  key: const ValueKey('draft_row'),
                  controller: _draftController,
                  onSubmit: _submitDraft,
                  onCancel: () {
                    _draftController.clear();
                    _pendingQuickAddSection = null;
                    _pendingQuickAddDay = null;
                    setState(() => _showDraft = false);
                  },
                );
                final rows = <Widget>[
                  // 桌面/两栏：参考图首行「新提醒事项」幽灵行；草稿态原位替换。
                  if (isPane && !_isTrashView)
                    _showDraft
                        ? draftRow
                        : _GhostNewRow(
                            onTap: () => setState(() => _showDraft = true),
                          ),
                  // #602「分区列排」：手动分区清单且开关打开时，每个分区一条横向列。
                  // 判据「有分区才分列」挂在这条 if 上——摘掉它，
                  // `section_columns_no_sections_test` 当场红（反向探针）。
                  if (ref.watch(sectionColumnsProvider) &&
                      widget.list.sections.isNotEmpty &&
                      query.trim().isEmpty)
                    _sectionColumnsView(sections, subtasksByParent)
                  else
                    for (final entry in sections.entries) ...[
                    if (!skipSectionHeader || entry.key != widget.list.title)
                      // #477：今天视图分区头作为拖放目标，拖入即改时间
                      DragTarget<String>(
                        key: ValueKey('drag_target_${entry.key}'),
                        onAcceptWithDetails: (details) {
                          _onSectionDrop(details.data, entry.key);
                        },
                        builder:
                            (
                              BuildContext context,
                              List<String?> candidateData,
                              List<dynamic> details,
                            ) {
                              return LifeSectionHeader(
                                title: entry.key,
                                sectionKey: ValueKey('section_${entry.key}'),
                                collapsed: _isCollapsed(
                                  ref.watch(collapsedKeysProvider),
                                  entry.key,
                                ),
                                onToggle: () => _toggleSection(entry.key),
                                onAdd:
                                    widget.list.id == 'smart.today' &&
                                        _canQuickAddToSection(entry.key)
                                    ? () => _quickAddToSection(entry.key)
                                    : null,
                              );
                            },
                      ),
                    if (!_isCollapsed(
                      ref.watch(collapsedKeysProvider),
                      entry.key,
                    ))
                      for (final item in entry.value)
                        // #477：今天视图行可拖动，拖到分区头即改时间
                        //
                        // #548：feedback 复用同一条行组件，而 Overlay 给反馈层的
                        // 宽度约束是无界的（`0.0<=w<=Infinity`），行里的标题用了
                        // `Expanded` → 起手即抛「children have non-zero flex but
                        // incoming width constraints are unbounded」。这里用
                        // LayoutBuilder 把源行的实际宽度交给反馈层，`Expanded`
                        // 重新有界，跟手卡片也与源行同宽。
                        LayoutBuilder(
                          builder: (context, constraints) => Draggable<String>(
                            key: ValueKey('draggable_${item.id}'),
                            data: item.id,
                            feedback: SizedBox(
                              key: ValueKey('drag_feedback_${item.id}'),
                              width: constraints.maxWidth,
                              child: _buildItemRow(
                                item,
                                subtasksByParent: subtasksByParent,
                              ),
                            ),
                            child: _buildItemRow(
                              item,
                              subtasksByParent: subtasksByParent,
                            ),
                          ),
                        ),
                    // #487 面②：Apple「计划」视图每个日期组末尾一条空圆圈，
                    // 点它即在**那一天**新建（guide zh-cn/12：add reminders at the
                    // bottom of the section）。零条目的骨架组也要有——这正是骨架
                    // 存在的意义；折叠态收起时不铺。
                    if (widget.list.id == 'smart.scheduled' &&
                        !_isCollapsed(
                          ref.watch(collapsedKeysProvider),
                          entry.key,
                        ) &&
                        layout.dayByKey.containsKey(entry.key))
                      _SectionQuickCreateRow(
                        key: ValueKey('quick_create_${entry.key}'),
                        onTap: () => _quickAddToSection(
                          entry.key,
                          day: layout.dayByKey[entry.key],
                        ),
                      ),
                  ],
                  // 紧凑端保留底部工具条入口，草稿行仍落在列表体末尾。
                  if (!isPane && _showDraft) draftRow,
                ];

                return Column(
                  children: [
                    if (_isTrashView)
                      const _TrashHeader()
                    else
                      _ListHeaderToolbar(
                        list: widget.list,
                        isPane: isPane,
                        remainingCount: remainingCount,
                        doneCount: doneCount,
                        onClearCompleted: doneCount == 0
                            ? null
                            : () => _clearCompleted(
                                all
                                    .where(
                                      (e) =>
                                          e.isCompleted && e.parentId == null,
                                    )
                                    .map((e) => e.id)
                                    .toList(growable: false),
                              ),
                      ),
                    // 主体：空列表 = 空态引导（可点新建）；_showDraft 时草稿行进列表体
                    Expanded(
                      child: _isTrashView && items.isEmpty && !isSearchEmpty
                          // #163：回收站空态（原先落到空 ListView → 整页空白）
                          ? const Center(
                              key: ValueKey('trash_empty'),
                              child: Text(
                                '没有最近删除的提醒事项',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: ReminderTokens.labelSecondary,
                                ),
                              ),
                            )
                          : isListEmpty
                          ? Column(
                              children: [
                                if (isPane && !_isTrashView)
                                  _GhostNewRow(
                                    onTap: () =>
                                        setState(() => _showDraft = true),
                                  ),
                                Expanded(
                                  child: GestureDetector(
                                    key: const ValueKey('empty_new_hint'),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _openNewItemDialog,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.plus_circle,
                                            size: 40,
                                            color: Color(
                                              widget.list.colorArgb,
                                            ).withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            '没有提醒',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color:
                                                  ReminderTokens.labelSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            '点按此处或「＋ 新提醒事项」添加',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  ReminderTokens.labelTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView(children: rows),
                    ),
                  ],
                );
              },
            ),
          ),
          // 桌面/两栏用首行幽灵行；紧凑端保留底部工具条。最近删除无入口。
          if (!_isTrashView && !isPane)
            GestureDetector(
              key: const ValueKey('bottom_new_item'),
              onTap: _openNewItemDialog,
              child: Container(
                width: double.infinity,
                color: CupertinoColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.plus_circle_fill,
                      size: 22,
                      color: ReminderTokens.systemBlue,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '新提醒事项',
                      style: TextStyle(
                        fontSize: 15,
                        color: ReminderTokens.systemBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// #487 面②：一次分区构建的两个产物——组序 + 「组键 → 具体那一天」。
///
/// `dayByKey` 只收**能定位到某一天**的组（见 [_daySections]），组末快捷行据此铺。
class _SectionLayout {
  const _SectionLayout(this.sections, this.dayByKey);

  final Map<String, List<ReminderItem>> sections;
  final Map<String, DateTime> dayByKey;
}

/// #487 面②：Apple「计划」视图日期组末尾的空圆圈行——只有圈、没有文字，
/// 点它即在**该组那一天**开草稿（与列表行左侧未勾选的圆圈同一形状，见 ReminderRow）。
class _SectionQuickCreateRow extends StatelessWidget {
  const _SectionQuickCreateRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.circle,
              color: CupertinoDynamicColor.resolve(
                ReminderTokens.labelTertiary,
                context,
              ),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// 参考图主列表首行「新提醒事项」幽灵行（桌面/两栏）。
class _GhostNewRow extends StatelessWidget {
  const _GhostNewRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('ghost_new_item'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.add_circled,
              color: CupertinoDynamicColor.resolve(
                ReminderTokens.labelTertiary,
                context,
              ),
              size: 22,
            ),
            const SizedBox(width: 14),
            const Icon(
              CupertinoIcons.add,
              color: ReminderTokens.systemBlue,
              size: 16,
            ),
            const SizedBox(width: 4),
            const Text(
              '新提醒事项',
              style: TextStyle(fontSize: 15, color: ReminderTokens.systemBlue),
            ),
          ],
        ),
      ),
    );
  }
}

/// 新建提醒草稿行：提交才 upsertItem 落库；空标题丢弃。
class _DraftRow extends StatefulWidget {
  const _DraftRow({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  State<_DraftRow> createState() => _DraftRowState();
}

class _DraftRowState extends State<_DraftRow> {
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChanged);

  /// #367：Apple 语义「点到别处即提交」。
  ///
  /// 此前草稿行只认 Return 与提交按钮，失焦什么都不做——于是点别处后草稿行会以
  /// 「像已存在」的形态常驻列表（右侧还挂着提交箭头），而计数又不含它。
  void _onFocusChanged() {
    if (_focusNode.hasFocus || !mounted) return;
    widget.onSubmit();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.circle,
            color: ReminderTokens.labelTertiary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: CupertinoTextField(
              key: const ValueKey('draft_field'),
              controller: widget.controller,
              focusNode: _focusNode,
              autofocus: true,
              onSubmitted: (_) => widget.onSubmit(),
              placeholder: '新提醒事项',
              decoration: const BoxDecoration(),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          CupertinoButton(
            key: const ValueKey('draft_submit'),
            minimumSize: Size.zero,
            padding: const EdgeInsets.all(6),
            onPressed: widget.onSubmit,
            child: const Icon(
              CupertinoIcons.arrow_up,
              size: 20,
              color: ReminderTokens.systemBlue,
            ),
          ),
        ],
      ),
    );
  }
}

/// 最近删除头部（TC-UI-109）：Apple Recently Deleted 有标题与保留期说明。
/// 旧实现在 pane 档跳过表头且无空态 → 整页空白（#163）。
class _TrashHeader extends StatelessWidget {
  const _TrashHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('trash_header'),
      padding: EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近删除',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: ReminderTokens.labelSecondary,
              height: 1.1,
            ),
          ),
          SizedBox(height: 2),
          Text(
            '项目将在删除 30 天后永久移除',
            style: TextStyle(
              fontSize: 13,
              color: ReminderTokens.labelSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 列表头（图2）：列表色大标题 + 「N 项完成 · 清除」+ 右侧大计数/显示/排序。
class _ListHeaderToolbar extends ConsumerWidget {
  const _ListHeaderToolbar({
    required this.list,
    required this.isPane,
    required this.remainingCount,
    required this.doneCount,
    this.onClearCompleted,
  });

  final ReminderList list;
  final bool isPane;
  final int remainingCount;
  final int doneCount;
  final VoidCallback? onClearCompleted;

  static const _sortLabels = {
    ListSortMode.manual: '手动',
    ListSortMode.dueDate: '按到期日',
    ListSortMode.createdDate: '按创建日期',
    ListSortMode.title: '按标题',
    ListSortMode.priority: '按优先级',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // #256：Apple 的「显示已完成」按列表记忆（默认隐藏；不回落全局，否则串台）
    final bool showCompleted =
        ref.watch(showCompletedByListProvider)[list.id] ?? false;
    final sortMode = ref.watch(listSortModeProvider);
    final titleColor = Color(list.colorArgb);
    return Padding(
      key: const ValueKey('list_header_toolbar'),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPane)
                  Padding(
                    key: const ValueKey('list_large_title'),
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      list.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        height: 1.1,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      '$doneCount 项完成',
                      key: const ValueKey('done_count'),
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoDynamicColor.resolve(
                          ReminderTokens.labelSecondary,
                          context,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoDynamicColor.resolve(
                          ReminderTokens.labelSecondary,
                          context,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      key: const ValueKey('clear_completed'),
                      onPressed: doneCount == 0 ? null : onClearCompleted,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      disabledColor: CupertinoDynamicColor.resolve(
                        ReminderTokens.labelTertiary,
                        context,
                      ),
                      child: const Text('清除', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isPane && !list.isSmart)
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 0),
              child: Text(
                '$remainingCount',
                key: const ValueKey('remaining_count'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                  height: 1,
                ),
              ),
            ),
          // 显示 ▾（TC-UI-108）
          _CupertinoMenu<bool>(
            anchorKey: const ValueKey('toggle_show_completed'),
            semanticsLabel: '显示',
            items: const [
              _MenuItem(value: true, label: '显示已完成'),
              _MenuItem(value: false, label: '隐藏已完成'),
            ],
            current: showCompleted,
            onSelected: (v) => ref
                .read(showCompletedByListProvider.notifier)
                .setFor(list.id, v),
            anchor: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  showCompleted ? '显示 ✓' : '显示',
                  style: const TextStyle(
                    fontSize: 13,
                    color: ReminderTokens.systemBlue,
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 12,
                  color: ReminderTokens.systemBlue,
                ),
              ],
            ),
          ),
          // 排序 ▾（TC-UI-111）
          _CupertinoMenu<ListSortMode>(
            anchorKey: const ValueKey('sort_menu'),
            semanticsLabel: '排序',
            items: [
              for (final e in ListSortMode.values)
                _MenuItem(value: e, label: _sortLabels[e]!),
            ],
            current: sortMode,
            onSelected: (m) => ref.read(listSortModeProvider.notifier).set(m),
            anchor: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '排序',
                  style: TextStyle(
                    fontSize: 13,
                    color: ReminderTokens.systemBlue,
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 12,
                  color: ReminderTokens.systemBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 分区头（线框客户端「分区一 ∨」）：标题 + 条数 + 折叠箭头。
/// 0.5px 发丝分隔线。
class _Hairline extends StatelessWidget {
  const _Hairline({this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: EdgeInsets.only(left: indent),
      color: CupertinoDynamicColor.resolve(ReminderTokens.separator, context),
    );
  }
}

class _VerticalHairline extends StatelessWidget {
  const _VerticalHairline();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CupertinoDynamicColor.resolve(ReminderTokens.separator, context),
      child: const SizedBox(width: 0.5),
    );
  }
}

/// 紧凑首页「我的列表」行：24px 彩色圆角图标 + 标题 + 计数 + 指示箭头。
class _HomeListRow extends StatelessWidget {
  const _HomeListRow({
    required this.list,
    required this.onTap,
    this.isTrash = false,
  });

  final ReminderList list;
  final VoidCallback onTap;
  final bool isTrash;

  @override
  Widget build(BuildContext context) {
    final color = isTrash
        ? CupertinoDynamicColor.resolve(ReminderTokens.labelSecondary, context)
        : Color(list.colorArgb);
    final icon = isTrash
        ? CupertinoIcons.trash
        : list.listType == ReminderListType.grocery
        ? CupertinoIcons.cart
        : CupertinoIcons.list_bullet;
    return GestureDetector(
      // #588：紧凑档首页的行也要有可寻址句柄，否则「置顶后这行该不该消失」
      // 只能靠文案位置间接判，会被卡片区里同名的标题满足。
      key: ValueKey('home_list_${list.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(LifeRadius.sm),
              ),
              child: Icon(icon, color: CupertinoColors.white, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(list.title, style: const TextStyle(fontSize: 16)),
            ),
            Text(
              '${list.itemCount}',
              style: const TextStyle(color: ReminderTokens.labelSecondary),
            ),
            const SizedBox(width: 4),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: ReminderTokens.labelTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 弹出菜单条目（value 为 null = 置灰不可选）。
class _MenuItem<T> {
  const _MenuItem({this.value, required this.label});

  final T? value;
  final String label;
}

/// iOS 风格弹出菜单（替换 Material PopupMenuButton）：锚点按钮 +
/// [CupertinoMenuAnchor] 浮层；当前值带 ✓。
class _CupertinoMenu<T> extends StatelessWidget {
  const _CupertinoMenu({
    required this.anchorKey,
    required this.anchor,
    required this.items,
    required this.current,
    required this.onSelected,
    this.semanticsLabel,
  });

  final Key anchorKey;
  final Widget anchor;
  final List<_MenuItem<T>> items;
  final T? current;
  final ValueChanged<T> onSelected;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return CupertinoMenuAnchor(
      menuChildren: [
        for (final item in items)
          CupertinoMenuItem(
            onPressed: item.value == null
                ? null
                : () => onSelected(item.value as T),
            trailing: item.value != null && item.value == current
                ? const Icon(CupertinoIcons.checkmark, size: 14)
                : null,
            child: Text(item.label),
          ),
      ],
      builder: (context, controller, child) {
        final button = CupertinoButton(
          key: anchorKey,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          onPressed: () => controller.open(),
          child: anchor,
        );
        if (semanticsLabel == null) return button;
        return Semantics(label: semanticsLabel, button: true, child: button);
      },
    );
  }
}

/// 列表「更多」菜单（⋯）：显示已完成开关 + 分区入口（#533 替掉原置灰占位）。
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.onToggleCompleted,
    required this.showCompleted,
    required this.sectionsEnabled,
    required this.onNewSection,
    required this.onEditSections,
    required this.selectionCount,
    required this.selecting,
    required this.onCreateFromSelection,
    required this.onExitSelection,
    required this.shareEnabled,
    required this.onShareList,
  });

  final VoidCallback onToggleCompleted;
  final bool showCompleted;
  final bool sectionsEnabled;
  final VoidCallback onNewSection;
  final VoidCallback onEditSections;
  final int selectionCount;
  final bool selecting;
  final VoidCallback onCreateFromSelection;
  final VoidCallback onExitSelection;

  /// flutter#570：共享入口。智能清单是派生视图、没有成员表，故只普通列表出这一项。
  final bool shareEnabled;
  final VoidCallback onShareList;

  @override
  Widget build(BuildContext context) {
    return _CupertinoMenu<String>(
      anchorKey: const ValueKey('list_more_menu'),
      semanticsLabel: '更多',
      items: [
        _MenuItem(
          value: showCompleted ? 'hide-completed' : 'toggle-completed',
          label: showCompleted ? '隐藏已完成' : '显示已完成',
        ),
        // #533：智能列表没有分区（分区属用户列表），故只普通列表出这两个入口。
        if (sectionsEnabled) ...[
          const _MenuItem(value: 'new-section', label: '新建分区'),
          const _MenuItem(value: 'edit-sections', label: '编辑分区…'),
          // flutter #567：Apple「文件 ▸ 用所选项目新建分区」。
          // 一条都没有选中时 value=null ⇒ 这一项**置灰不可点**（判据 2 的另一半）。
          _MenuItem(
            value: selectionCount > 0 ? 'section-from-selection' : null,
            label: '用所选项目新建分区',
          ),
        ],
        if (selecting) const _MenuItem(value: 'exit-selection', label: '取消选择'),
        if (shareEnabled) const _MenuItem(value: 'share-list', label: '共享…'),
      ],
      current: 'toggle-completed',
      onSelected: (v) {
        if (v == 'toggle-completed' || v == 'hide-completed') {
          onToggleCompleted();
        } else if (v == 'new-section') {
          onNewSection();
        } else if (v == 'edit-sections') {
          onEditSections();
        } else if (v == 'section-from-selection') {
          onCreateFromSelection();
        } else if (v == 'exit-selection') {
          onExitSelection();
        } else if (v == 'share-list') {
          onShareList();
        }
      },
      anchor: const Icon(CupertinoIcons.ellipsis_circle),
    );
  }
}
