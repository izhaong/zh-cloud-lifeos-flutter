import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'design/reminder_tokens.dart';
import 'providers.dart';
import 'widgets/new_list_dialog.dart';
import 'widgets/reminder_detail_pane.dart';
import 'widgets/reminder_row.dart';
import 'widgets/smart_list_card.dart';
import 'widgets/task_settings_sheet.dart';
import 'widgets/task_shortcuts.dart';
import 'widgets/task_sidebar.dart';

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
    final sizeClass =
        WindowSizeClass.fromWidth(MediaQuery.of(context).size.width);
    final listsAsync = ref.watch(reminderListsProvider);

    return listsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (lists) {
        // 快捷键层（⌘N 新建 / ⌘F 搜索）包裹三档外壳；触屏端无物理键不影响
        final panes = TaskShortcuts(
          child: switch (sizeClass) {
          WindowSizeClass.compact => openListId == null
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
            Material(
              color: ReminderTokens.windowBg,
              child: Row(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Text('已完成'),
                    ),
                  ),
                  TextButton(
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
        .where((e) => e.isSmart && e.id != 'smart.trash')
        .toList(growable: false);
    final mine = lists.where((e) => !e.isSmart).toList(growable: false);
    final trash = lists.where((e) => e.id == 'smart.trash').firstOrNull;
    final hasGrocery =
        mine.any((e) => e.listType == ReminderListType.grocery);
    final query = ref.watch(searchQueryProvider).trim();
    final searching = query.isNotEmpty;

    // iOS 提醒事项「列表」首页：大标题 + 搜索 + 智能卡片 + 我的列表。
    // 嵌在生活台壳内时，壳应用栏常显；本页不再另起全屏路由。
    return Scaffold(
      backgroundColor: ReminderTokens.windowBg,
      appBar: AppBar(
        backgroundColor: ReminderTokens.windowBg,
        surfaceTintColor: Colors.transparent,
        title: const Text('列表'),
        actions: [
          IconButton(
            key: const ValueKey('home_edit_placeholder'),
            tooltip: '编辑（规划）',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('编辑列表 · 规划占位')),
              );
            },
            icon: const Icon(CupertinoIcons.ellipsis_circle),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          TextField(
            key: const ValueKey('home_search'),
            onChanged: (v) => ref.read(searchQueryProvider.notifier).set(v),
            decoration: InputDecoration(
              hintText: '搜索',
              prefixIcon: const Icon(CupertinoIcons.search, size: 20),
              filled: true,
              fillColor: ReminderTokens.separator,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (searching)
            _HomeSearchResults(
              query: query,
              onSelectItem: onSelectItem,
            )
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
            if (!hasGrocery)
              ListTile(
                key: const ValueKey('suggested_grocery_home'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(CupertinoIcons.cart_fill,
                    color: ReminderTokens.systemGreen),
                title: const Text('建议列表：日常采购'),
                trailing: IconButton(
                  key: const ValueKey('suggested_grocery_home_add'),
                  icon: const Icon(CupertinoIcons.add_circled_solid,
                      color: ReminderTokens.systemGreen),
                  onPressed: () => _createSuggestedGrocery(ref),
                ),
                onTap: () => _createSuggestedGrocery(ref),
              ),
            const SizedBox(height: 20),
            Text(
              '我的列表',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF8E8E93),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < mine.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 52),
                    ListTile(
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(mine[i].colorArgb),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(CupertinoIcons.list_bullet,
                            color: Colors.white, size: 15),
                      ),
                      title: Text(mine[i].title),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${mine[i].itemCount}',
                            style: const TextStyle(color: Color(0xFF8E8E93)),
                          ),
                          const Icon(CupertinoIcons.chevron_forward,
                              size: 16, color: Color(0xFFC7C7CC)),
                        ],
                      ),
                      onTap: () => onOpenList?.call(mine[i].id),
                    ),
                  ],
                  const Divider(height: 1, indent: 52),
                  ListTile(
                    leading: const Icon(CupertinoIcons.add_circled_solid,
                        color: Color(0xFF007AFF)),
                    title: const Text('添加列表',
                        style: TextStyle(color: Color(0xFF007AFF))),
                    onTap: () => showNewListDialog(
                      context,
                      onCreate: (list) => ref
                          .read(reminderRepositoryProvider)
                          .upsertList(list),
                    ),
                  ),
                  if (trash != null) ...[
                    const Divider(height: 1, indent: 52),
                    ListTile(
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: ReminderTokens.labelSecondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(CupertinoIcons.trash,
                            color: Colors.white, size: 15),
                      ),
                      title: Text(trash.title),
                      trailing: Text(
                        '${trash.itemCount}',
                        style: const TextStyle(
                            color: ReminderTokens.labelSecondary),
                      ),
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
    ref.read(reminderRepositoryProvider).upsertList(
          ReminderList.createGroceryList(id: id, title: '日常采购'),
        );
  }
}

/// 首页搜索结果：复用「全部」过滤；空态文案对齐线框。
class _HomeSearchResults extends ConsumerWidget {
  const _HomeSearchResults({
    required this.query,
    this.onSelectItem,
  });

  final String query;
  final ValueChanged<ReminderItem>? onSelectItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(filteredItemsForListProvider('smart.all'));
    final repo = ref.watch(reminderRepositoryProvider);
    return itemsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
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
                style: TextStyle(color: Color(0xFF8E8E93)),
              ),
            ),
          );
        }
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 56),
                ReminderRow(
                  item: items[i],
                  onToggleCompleted: () =>
                      completeReminder(ref, items[i]),
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
      return const Scaffold(
        backgroundColor: ReminderTokens.windowBg,
        body: Center(child: Text('列表不存在')),
      );
    }
    return ListContentPane(
      list: list,
      onSelectItem: onSelectItem,
      listTitles: {for (final l in lists) l.id: l.title},
      leading: onBack == null
          ? null
          : TextButton.icon(
              onPressed: onBack,
              icon: const Icon(CupertinoIcons.back, size: 18),
              label: const Text('列表'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF007AFF),
                padding: const EdgeInsets.only(left: 4),
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
          const VerticalDivider(width: 1, color: ReminderTokens.separator),
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
                      : IconButton(
                          key: const ValueKey('show_sidebar'),
                          tooltip: '显示侧栏',
                          onPressed: () => ref
                              .read(sidebarVisibleProvider.notifier)
                              .set(true),
                          icon: const Icon(Icons.view_sidebar_outlined),
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
      data: (items) =>
          items.where((e) => e.id == _selectedId).firstOrNull,
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
          const VerticalDivider(width: 1, color: ReminderTokens.separator),
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
                      : IconButton(
                          key: const ValueKey('show_sidebar'),
                          tooltip: '显示侧栏',
                          onPressed: () => ref
                              .read(sidebarVisibleProvider.notifier)
                              .set(true),
                          icon: const Icon(Icons.view_sidebar_outlined),
                        ),
                ),
        ),
        if (selected != null) ...[
          const VerticalDivider(width: 1, color: ReminderTokens.separator),
          SizedBox(
            width: 320,
            child: KeyedSubtree(
              key: ValueKey('inspector_${selected.id}'),
              child: ReminderDetailPane(
              item: selected,
                  onSaved: (updated) =>
                      ref.read(reminderRepositoryProvider)
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
  const _EmptyOverview({
    this.showSidebarButton = false,
    this.onShowSidebar,
  });

  final bool showSidebarButton;
  final VoidCallback? onShowSidebar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: showSidebarButton
          ? AppBar(
              leading: IconButton(
                key: const ValueKey('show_sidebar'),
                tooltip: '显示侧栏',
                onPressed: onShowSidebar,
                icon: const Icon(Icons.view_sidebar_outlined),
              ),
            )
          : null,
      body: const Center(child: Text('选择一个列表')),
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
  final _collapsedSections = <String>{};

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
  Map<String, List<ReminderItem>> _buildSections(
    List<ReminderItem> topLevel,
  ) {
    final manual = widget.list.sections;
    if (manual.isNotEmpty) {
      final byId = {
        for (final s in manual) s.id: s,
      };
      final sections = <String, List<ReminderItem>>{};
      // 元数据序建桶（空分区也显示头，Apple 同款）
      for (final s in manual) {
        sections.putIfAbsent(s.title, () => []);
      }
      for (final item in topLevel) {
        final sec = item.sectionId == null
            ? null
            : byId[item.sectionId];
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
      final now = DateTime.now();
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

    final now = DateTime.now();
    final sections = <String, List<ReminderItem>>{};
    for (final item in topLevel) {
      final key = item.dueAt == null
          ? '无日期'
          : _sectionLabel(item.dueAt!, now);
      sections.putIfAbsent(key, () => []).add(item);
    }
    return sections;
  }

  static String _sectionLabel(DateTime due, DateTime now) {
    final isToday = due.year == now.year &&
        due.month == now.month &&
        due.day == now.day;
    if (isToday) return '今天';
    if (due.isBefore(now)) return '已过期';
    final isTomorrow = due.year == now.year &&
        due.month == now.month &&
        due.day == now.day + 1;
    if (isTomorrow) return '明天';
    return '${due.month}月${due.day}日';
  }

  void _toggleSection(String key) {
    setState(() {
      if (!_collapsedSections.remove(key)) {
        _collapsedSections.add(key);
      }
    });
  }

  /// 列表内排序（TC-UI-111）：manual=仓库契约序；其余视图序即时生效、
  /// 不写回 sortOrder（线框「排序 ▾」语义）。
  List<ReminderItem> _sortTopLevel(List<ReminderItem> items) {
    final mode = ref.read(listSortModeProvider);
    final sorted = [...items];
    switch (mode) {
      case ListSortMode.manual:
        return items;
      case ListSortMode.dueDate:
        sorted.sort((a, b) => (a.dueAt ?? DateTime(2999, 1, 1))
            .compareTo(b.dueAt ?? DateTime(2999, 1, 1)));
      case ListSortMode.title:
        sorted.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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
    final row = ReminderRow(
      item: item,
      listName: listName,
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
              TextButton(
                key: ValueKey('restore_${item.id}'),
                onPressed: () => repo.restoreItem(item.id),
                child: const Text('恢复',
                    style: TextStyle(color: Color(0xFF007AFF))),
              ),
            ],
          )
        : row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        trashRow,
        for (final sub in subtasksByParent[item.id] ??
            const <ReminderItem>[])
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: ReminderRow(
              item: sub,
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
        listId: _isSmartView ? 'list.personal' : widget.list.id,
        title: title,
        // 从「今天」/「计划」视图新建 → dueAt = 今天（命中 today 同日过滤 + scheduled 非空过滤）；
        // 从「全部/旗标/已完成」视图新建 → 不设 dueAt（归入个人列表，全部视图可见）
        dueAt: (widget.list.id == 'smart.today' ||
                widget.list.id == 'smart.scheduled')
            ? now
            : null,
      ),
    );
    _draftController.clear();
    setState(() => _showDraft = false);
  }

  Future<void> _openNewItemDialog() async {
    // TODO(reminders-parity): 智能视图内的新建提醒应引导选择目标列表（P1）
    setState(() => _showDraft = true);
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync =
        ref.watch(filteredItemsForListProvider(widget.list.id));
    // 计数用未过滤流（已完成默认隐藏后，头部仍要能报「N 项完成」）
    final allItemsAsync = ref.watch(itemsForListProvider(widget.list.id));
    final query = ref.watch(searchQueryProvider);
    // 排序态驱动列表体重建（TC-UI-111：切换即时生效）
    ref.watch(listSortModeProvider);
    final isPane = WindowSizeClass.fromWidth(
      MediaQuery.of(context).size.width,
    ).isPaneLayout;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // 桌面三栏不显示返回箭头（参考图主区直接是标题/工具条）。
        automaticallyImplyLeading: !isPane && widget.leading == null,
        leading: widget.leading,
        leadingWidth: widget.leading == null ? null : 96,
        // macOS 大标题口径（图2）：宽屏 AppBar 不放标题，标题进内容区（列表色大字）
        title: isPane ? null : Text(widget.list.title),
        actions: [
          if (isPane)
            SizedBox(
              width: 220,
              child: TextField(
                key: const ValueKey('toolbar_search'),
                focusNode: _searchFocus,
                onChanged: (v) =>
                    ref.read(searchQueryProvider.notifier).set(v),
                decoration: InputDecoration(
                  hintText: '搜索',
                  prefixIcon: const Icon(CupertinoIcons.search,
                      size: 16, color: Color(0xFF8E8E93)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        width: 0.5, color: Color(0xFFD1D1D6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        width: 0.5, color: Color(0xFFD1D1D6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        width: 1, color: Color(0xFF007AFF)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFFFFFF),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          // 顶栏 ＋（图2 工具行；与 ⌘N 同构→草稿行）
          if (isPane)
            IconButton(
              key: const ValueKey('toolbar_new_item'),
              tooltip: '新提醒（⌘N）',
              onPressed: _openNewItemDialog,
              icon: const Icon(CupertinoIcons.add),
            ),
          PopupMenuButton<String>(
            key: const ValueKey('list_more_menu'),
            tooltip: '更多',
            onSelected: (v) {
              if (v == 'toggle-completed') {
                final cur = ref.read(showCompletedProvider);
                ref.read(showCompletedProvider.notifier).set(!cur);
              }
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'toggle-completed',
                checked: ref.read(showCompletedProvider),
                child: const Text('显示已完成'),
              ),
              const PopupMenuItem(
                value: 'clear-sections',
                enabled: false,
                child: Text('按分区整理（规划）'),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.more_horiz),
            ),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (items) {
          final isSearchEmpty = query.trim().isNotEmpty && items.isEmpty;
          final isListEmpty = items.isEmpty && !_isTrashView && !isSearchEmpty && !_showDraft;
          if (isSearchEmpty) {
            return const Center(
              key: Key('search_empty'),
              child: Text('无匹配结果'),
            );
          }
          // 顶层与子任务分组（watchItems 返回全层级；孤儿/环按顶层兜底）
          final itemsById = {
            for (final e in items) e.id: e,
          };
          final topLevel = _sortTopLevel(
            items.where((e) {
              if (e.parentId == null) return true;
              // 孤儿（父不在结果集）或自环 → 按顶层渲染
              return !itemsById.containsKey(e.parentId) || e.parentId == e.id;
            }).toList(growable: false),
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
          final all = allItemsAsync.asData?.value ?? const <ReminderItem>[];
          final doneCount =
              all.where((e) => e.isCompleted && e.parentId == null).length;
          final remainingCount =
              all.where((e) => !e.isCompleted && e.parentId == null).length;

          // 分区（线框客户端「分区一 ∨」）：带 dueAt 的顶层条目按日桶折叠；
          // 无日期条目单独一区。折叠为内存态（P1 不持久化）。
          // smart.today/smart.scheduled 视图：分区头与列表标题重复 → 跳过
          final skipSectionHeader = widget.list.id == 'smart.today' ||
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
                _SectionHeader(
                  title: entry.key,
                  collapsed: _collapsedSections.contains(entry.key),
                  onToggle: () => _toggleSection(entry.key),
                ),
              if (!_collapsedSections.contains(entry.key))
                for (final item in entry.value)
                  _buildItemRow(
                    item,
                    subtasksByParent: subtasksByParent,
                  ),
            ],
            // 紧凑端保留底部工具条入口，草稿行仍落在列表体末尾。
            if (!isPane && _showDraft) draftRow,
          ];

          return Column(
            children: [
              if (!_isTrashView)
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
                                    (e) => e.isCompleted && e.parentId == null)
                                .map((e) => e.id)
                                .toList(growable: false),
                          ),
                ),
              // 主体：空列表 = 空态引导（可点新建）；_showDraft 时草稿行进列表体
              Expanded(
                child: isListEmpty
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
                                    Icon(CupertinoIcons.plus_circle,
                                        size: 40,
                                        color: Color(widget.list.colorArgb)
                                            .withValues(alpha: 0.5)),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '没有提醒',
                                      style: TextStyle(
                                          fontSize: 17,
                                          color: Color(0xFF8E8E93)),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '点按此处或「＋ 新提醒事项」添加',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFC7C7CC)),
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

      // 桌面/两栏用首行幽灵行；紧凑端保留底部工具条。最近删除无入口。
      bottomNavigationBar: _isTrashView || isPane
          ? null
          : GestureDetector(
        key: const ValueKey('bottom_new_item'),
        onTap: _openNewItemDialog,
        child: const BottomAppBar(
          elevation: 0,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.plus_circle_fill,
                      size: 22, color: Color(0xFF007AFF)),
                  SizedBox(width: 6),
                  Text('新提醒事项',
                      style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF007AFF),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
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
    return InkWell(
      key: const ValueKey('ghost_new_item'),
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(CupertinoIcons.add_circled,
                color: ReminderTokens.labelTertiary, size: 22),
            SizedBox(width: 14),
            Icon(CupertinoIcons.add, color: ReminderTokens.systemBlue, size: 16),
            SizedBox(width: 4),
            Text(
              '新提醒事项',
              style: TextStyle(
                fontSize: 15,
                color: ReminderTokens.systemBlue,
              ),
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
          const Icon(CupertinoIcons.circle, color: Color(0xFFC7C7CC)),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                hintText: '新提醒事项',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_return,
                size: 20, color: Color(0xFF007AFF)),
            onPressed: onSubmit,
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
    ListSortMode.title: '按标题',
    ListSortMode.priority: '按优先级',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCompleted = ref.watch(showCompletedProvider);
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: ReminderTokens.labelSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      '·',
                      style: TextStyle(
                        fontSize: 13,
                        color: ReminderTokens.labelSecondary,
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('clear_completed'),
                      onPressed: doneCount == 0 ? null : onClearCompleted,
                      style: TextButton.styleFrom(
                        foregroundColor: ReminderTokens.systemBlue,
                        disabledForegroundColor: ReminderTokens.labelTertiary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          PopupMenuButton<bool>(
            key: const ValueKey('toggle_show_completed'),
            tooltip: '显示',
            initialValue: showCompleted,
            onSelected: (v) =>
                ref.read(showCompletedProvider.notifier).set(v),
            itemBuilder: (_) => const [
              CheckedPopupMenuItem(
                value: true,
                child: Text('显示已完成'),
              ),
              CheckedPopupMenuItem(
                value: false,
                child: Text('隐藏已完成'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(showCompleted ? '显示 ✓' : '显示',
                      style: const TextStyle(
                          fontSize: 13, color: ReminderTokens.systemBlue)),
                  const Icon(Icons.arrow_drop_down,
                      size: 16, color: ReminderTokens.systemBlue),
                ],
              ),
            ),
          ),
          // 排序 ▾（TC-UI-111）
          PopupMenuButton<ListSortMode>(
            key: const ValueKey('sort_menu'),
            tooltip: '排序',
            initialValue: sortMode,
            onSelected: (m) =>
                ref.read(listSortModeProvider.notifier).set(m),
            itemBuilder: (_) => [
              for (final e in ListSortMode.values)
                CheckedPopupMenuItem(
                  value: e,
                  checked: e == sortMode,
                  child: Text(_sortLabels[e]!),
                ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('排序',
                      style: TextStyle(
                          fontSize: 13, color: ReminderTokens.systemBlue)),
                  Icon(Icons.arrow_drop_down,
                      size: 16, color: ReminderTokens.systemBlue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分区头（线框客户端「分区一 ∨」）：标题 + 条数 + 折叠箭头。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.collapsed,
    required this.onToggle,
  });

  final String title;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('section_$title'),
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
              ),
            ),
            const Spacer(),
            Icon(
              collapsed
                  ? CupertinoIcons.chevron_down
                  : CupertinoIcons.chevron_up,
              size: 14,
              color: const Color(0xFF8E8E93),
            ),
          ],
        ),
      ),
    );
  }
}
