import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:app_core/app_core.dart';
import 'package:app_ui/app_ui.dart';

import 'design/reminder_tokens.dart';
import 'providers.dart';
import 'widgets/new_list_dialog.dart';
import 'widgets/reminder_detail_pane.dart';
import 'widgets/reminder_row.dart';
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
        // 快捷键层（⌘N 新建 / ⌘F 搜索）包裹三档外壳；触屏端无物理键不影响
        final panes = TaskShortcuts(
          child: switch (sizeClass) {
            WindowSizeClass.compact =>
              openListId == null
                  ? _CompactPane(
                      lists: lists,
                      onOpenList: onOpenList,
                      onSelectItem: onSelectItem,
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
            WindowSizeClass.expanded => _ThreePane(
              lists: lists,
              openListId: openListId,
              selectedItemId: selectedItemId,
              onOpenList: onOpenList,
              onSelectItem: onSelectItem,
              onOpenCloudLogin: onOpenCloudLogin,
            ),
          },
        );
        final undo = ref.watch(completionUndoProvider);
        if (undo == null) return panes;
        return Column(
          children: [
            ColoredBox(
              color: CupertinoDynamicColor.resolve(ReminderTokens.windowBg, context),
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
            Expanded(child: panes),
          ],
        );
      },
    );
  }
}

/// 紧凑单栏：iPhone 列表首页（智能列表卡片 + 我的列表 + 添加列表）。
/// 搜索有词时切换为「全部」过滤结果（线框：首页 → 搜索结果 / 空态）。
class _CompactPane extends ConsumerWidget {
  const _CompactPane({
    required this.lists,
    required this.onOpenList,
    this.onSelectItem,
  });

  final List<ReminderList> lists;
  final ValueChanged<String>? onOpenList;
  final ValueChanged<ReminderItem>? onSelectItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smart = lists
        .where((e) =>
            e.isSmart &&
            e.id != 'smart.trash' &&
            // 分配事项按批次裁定不出现在任务 UI（TC-API-121 降级口径；
            // 负向断言见 compact_home_visual_test / wireframe_gaps_test）
            e.id != 'smart.assigned')
        .toList(growable: false);
    final mine = lists.where((e) => !e.isSmart).toList(growable: false);
    final trash = lists.where((e) => e.id == 'smart.trash').firstOrNull;
    final hasGrocery = mine.any((e) => e.listType == ReminderListType.grocery);
    final query = ref.watch(searchQueryProvider).trim();
    final searching = query.isNotEmpty;

    // iOS 提醒事项「列表」首页：大标题 + 搜索 + 智能卡片 + 我的列表。
    // 嵌在生活台壳内时，壳应用栏常显；本页不再另起全屏路由。
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(ReminderTokens.windowBg, context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoDynamicColor.resolve(ReminderTokens.windowBg, context),
        automaticallyImplyLeading: false,
        middle: const Text('列表'),
        trailing: CupertinoButton(
          key: const ValueKey('home_edit_placeholder'),
          onPressed: () => showCupertinoDialog<void>(
            context: context,
            builder: (ctx) => LifeAlertDialog(
              title: const Text('编辑列表'),
              content: const Text('规划占位'),
              actions: [
                LifeDialogAction(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('好'),
                ),
              ],
            ),
          ),
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
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
              color: CupertinoDynamicColor.resolve(ReminderTokens.separator, context),
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
              itemCount: smart.length,
              itemBuilder: (context, i) {
                final list = smart[i];
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
        backgroundColor: CupertinoDynamicColor.resolve(ReminderTokens.windowBg, context),
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
          children: [
            if (sidebarVisible) ...[
              SizedBox(
                width: sidebarWidth,
                child: TaskSidebar(
                  lists: lists,
                  selectedListId: openListId,
                  onSelect: (l) => onOpenList?.call(l.id),
                  onAddList: () => showNewListDialog(
                    context,
                    onCreate: (list) =>
                        ref.read(reminderRepositoryProvider).upsertList(list),
                  ),
                  onToggleSidebar: () =>
                      ref.read(sidebarVisibleProvider.notifier).toggle(),
                  onOpenSettings: () => showTaskSettingsSheet(
                    context,
                    // 恒非 null 闭包会破坏「空=弱化文案」契约——传本体（null 即弱化）
                    onOpenCloudLogin: onOpenCloudLogin == null
                        ? null
                        : (_) => onOpenCloudLogin!.call(),
                  ),
                ),
              ),
              const _VerticalHairline(),
            ],
            Expanded(
              child: current == null
                  ? _EmptyOverview(
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
                  onOpenSettings: () => showTaskSettingsSheet(
                    context,
                    onOpenCloudLogin: widget.onOpenCloudLogin == null
                        ? null
                        : (_) => widget.onOpenCloudLogin!.call(),
                  ),
                ),
              ),
              const _VerticalHairline(),
            ],
            Expanded(
              child: current == null
                  ? _EmptyOverview(
                      showSidebarButton: !sidebarVisible,
                      onShowSidebar: () =>
                          ref.read(sidebarVisibleProvider.notifier).set(true),
                    )
                  : ListContentPane(
                      list: current,
                      onSelectItem: _handleSelect,
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
class ListContentPane extends ConsumerStatefulWidget {
  const ListContentPane({
    super.key,
    required this.list,
    this.onSelectItem,
    this.leading,
    this.listTitles,
  });

  final ReminderList list;
  final ValueChanged<ReminderItem>? onSelectItem;

  /// 紧凑端 AppBar 左侧返回（如「‹ 列表」）；null 时用系统默认（或无 leading）。
  final Widget? leading;

  /// 条目副标题用的真实列表名（智能视图下不是「今天/计划」）。
  final Map<String, String>? listTitles;

  @override
  ConsumerState<ListContentPane> createState() => _ListContentPaneState();
}

class _ListContentPaneState extends ConsumerState<ListContentPane> {
  final _draftController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _showDraft = false;
  TaskShortcutsController? _shortcuts;
  int _lastNewTicket = 0;
  int _lastSearchTicket = 0;
  int _lastNewListTicket = 0;
  bool _newListDialogOpen = false;

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
    });
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
    _shortcuts?.removeListener(_onShortcut);
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
  Map<String, List<ReminderItem>> _buildSections(List<ReminderItem> topLevel) {
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
      return ordered;
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
        if (due == null || (due.hour == 0 && due.minute == 0)) {
          buckets['今天']!.add(item);
        } else if (DateTime(due.year, due.month, due.day).isBefore(today)) {
          buckets['已过期']!.add(item);
        } else if (due.hour < 12) {
          buckets['上午']!.add(item);
        } else if (due.hour < 18) {
          buckets['下午']!.add(item);
        } else {
          buckets['今晚']!.add(item);
        }
      }
      return {
        for (final key in buckets.keys)
          if (buckets[key]!.isNotEmpty) key: buckets[key]!,
      };
    }

    final now = ref.read(clockProvider)();
    final sections = <String, List<ReminderItem>>{};
    for (final item in topLevel) {
      final key = item.dueAt == null ? '无日期' : _sectionLabel(item.dueAt!, now);
      sections.putIfAbsent(key, () => []).add(item);
    }
    return sections;
  }

  static String _sectionLabel(DateTime due, DateTime now) {
    final isToday =
        due.year == now.year && due.month == now.month && due.day == now.day;
    if (isToday) return '今天';
    if (due.isBefore(now)) return '已过期';
    final isTomorrow =
        due.year == now.year &&
        due.month == now.month &&
        due.day == now.day + 1;
    if (isTomorrow) return '明天';
    return '${due.month}月${due.day}日';
  }

  void _toggleSection(String key) {
    ref.read(collapsedKeysProvider.notifier).toggle(_collapsedKey(key));
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

  Widget _buildItemRow(
    ReminderItem item, {
    Map<String, List<ReminderItem>> subtasksByParent = const {},
  }) {
    final repo = ref.read(reminderRepositoryProvider);
    final listName = widget.listTitles?[item.listId] ?? widget.list.title;
    final subs = subtasksByParent[item.id] ?? const <ReminderItem>[];
    // parity#166：进度取全量流（智能视图会把子任务过滤掉，不能只看本列表）
    final progress = ref.watch(subtaskProgressProvider).value?[item.id];
    final row = ReminderRow(
      item: item,
      now: ref.read(clockProvider)(),
      listName: listName,
      subtaskDone: progress?.done ?? 0,
      subtaskTotal: progress?.total ?? 0,
      onToggleCompleted: () => completeReminder(ref, item),
      onToggleFlagged: () => repo.toggleFlagged(item.id),
      onTap: () => widget.onSelectItem?.call(item),
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
        trashRow,
        for (final sub in subs)
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: ReminderRow(
              item: sub,
              now: ref.read(clockProvider)(),
              listName: listName,
              dense: true,
              onToggleCompleted: () => completeReminder(ref, sub),
              onToggleFlagged: () => repo.toggleFlagged(sub.id),
              onDelete: _isTrashView ? null : () => repo.deleteItem(sub.id),
            ),
          ),
      ],
    );
  }

  Future<void> _submitDraft() async {
    final title = _draftController.text.trim();
    if (title.isEmpty) return; // 空标题不落库
    final repo = ref.read(reminderRepositoryProvider);
    // 智能视图内新建：必须落到对应视图的语义上——
    // today/scheduled/urgent 需要 dueAt 才能命中（smart.today 过滤 = !completed && 同日）；
    // 没有 dueAt 的条目只会出现在「全部」视图，在「今天」里不可见。
    final now = DateTime.now();
    await repo.upsertItem(
      ReminderItem(
        id: newReminderId(),
        listId: _isSmartView
            ? resolveSmartCreateListId(
                lists: (ref.read(reminderListsProvider).value ??
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
            (widget.list.id == 'smart.today' ||
                widget.list.id == 'smart.scheduled')
            ? DateTime(now.year, now.month, now.day)
            : null,
      ),
    );
    _draftController.clear();
    setState(() => _showDraft = false);
  }

  Future<void> _openNewItemDialog() async {
    // 智能视图的落点在 [_submitDraft] 里按「默认列表 → 首个自有列表」解析
    // （#245；Apple：智能列表里新建落到设置的 Default List）。
    setState(() => _showDraft = true);
  }

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
                final Map<String, bool> perList =
                    ref.read(showCompletedByListProvider);
                final bool cur = perList[widget.list.id] ?? false;
                ref
                    .read(showCompletedByListProvider.notifier)
                    .setFor(widget.list.id, !cur);
              },
              showCompleted:
                  ref.watch(showCompletedByListProvider)[widget.list.id] ??
                  false,
            ),
          ],
        ),
      ),
      child: Column(
        children: [
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
                final sections = _buildSections(topLevel);
                final draftRow = _DraftRow(
                  controller: _draftController,
                  onSubmit: _submitDraft,
                  onCancel: () {
                    _draftController.clear();
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
                  for (final entry in sections.entries) ...[
                    if (!skipSectionHeader || entry.key != widget.list.title)
                      LifeSectionHeader(
                        title: entry.key,
                        sectionKey: ValueKey('section_${entry.key}'),
                        collapsed: _isCollapsed(
                            ref.watch(collapsedKeysProvider), entry.key),
                        onToggle: () => _toggleSection(entry.key),
                      ),
                    if (!_isCollapsed(
                        ref.watch(collapsedKeysProvider), entry.key))
                      for (final item in entry.value)
                        _buildItemRow(item, subtasksByParent: subtasksByParent),
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
                                              color: ReminderTokens.labelSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            '点按此处或「＋ 新提醒事项」添加',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: ReminderTokens.labelTertiary,
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
              color: CupertinoDynamicColor.resolve(ReminderTokens.labelTertiary, context),
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
class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.controller,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(CupertinoIcons.circle, color: ReminderTokens.labelTertiary),
          const SizedBox(width: 14),
          Expanded(
            child: CupertinoTextField(
              key: const ValueKey('draft_field'),
              controller: controller,
              autofocus: true,
              onSubmitted: (_) => onSubmit(),
              placeholder: '新提醒事项',
              decoration: const BoxDecoration(),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          CupertinoButton(
            key: const ValueKey('draft_submit'),
            minimumSize: Size.zero,
            padding: const EdgeInsets.all(6),
            onPressed: onSubmit,
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
            style: TextStyle(fontSize: 13, color: ReminderTokens.labelSecondary),
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
                        color: CupertinoDynamicColor.resolve(ReminderTokens.labelSecondary, context),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoDynamicColor.resolve(ReminderTokens.labelSecondary, context),
                      ),
                    ),
                    CupertinoButton(
                      key: const ValueKey('clear_completed'),
                      onPressed: doneCount == 0 ? null : onClearCompleted,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      disabledColor: CupertinoDynamicColor.resolve(ReminderTokens.labelTertiary, context),
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
            onSelected: (v) =>
                ref.read(showCompletedByListProvider.notifier).setFor(list.id, v),
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

/// 列表「更多」菜单（⋯）：显示已完成开关 + 规划占位（置灰）。
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.onToggleCompleted,
    required this.showCompleted,
  });

  final VoidCallback onToggleCompleted;
  final bool showCompleted;

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
        const _MenuItem(value: null, label: '按分区整理（规划）'),
      ],
      current: 'toggle-completed',
      onSelected: (v) {
        if (v == 'toggle-completed' || v == 'hide-completed') {
          onToggleCompleted();
        }
      },
      anchor: const Icon(CupertinoIcons.ellipsis_circle),
    );
  }
}
