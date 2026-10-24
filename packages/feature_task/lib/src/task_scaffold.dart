import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'providers.dart';
import 'widgets/new_list_dialog.dart';
import 'widgets/reminder_detail_pane.dart';
import 'widgets/reminder_row.dart';
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
  });

  /// 紧凑端首页概览（列表首页）：智能列表卡片 + 我的列表。
  final String? openListId;

  /// 三栏第三列选中的提醒 id；空 = 不显示详情栏。
  final String? selectedItemId;

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
        return TaskShortcuts(
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
            ),
          WindowSizeClass.expanded => _ThreePane(
              lists: lists,
              openListId: openListId,
              selectedItemId: selectedItemId,
              onOpenList: onOpenList,
              onSelectItem: onSelectItem,
            ),
          },
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
    final smart = lists.where((e) => e.isSmart).toList(growable: false);
    final mine = lists.where((e) => !e.isSmart).toList(growable: false);
    final query = ref.watch(searchQueryProvider).trim();
    final searching = query.isNotEmpty;

    // iOS 提醒事项「列表」首页：大标题 + 搜索 + 智能卡片 + 我的列表。
    // 嵌在生活台壳内时，壳应用栏常显；本页不再另起全屏路由。
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
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
              fillColor: const Color(0xFFE5E5EA),
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
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                for (final list in smart
                  ..sort(
                      (a, b) => _smartOrder(a.id).compareTo(_smartOrder(b.id))))
                  _SmartCard(list: list, onTap: () => onOpenList?.call(list.id)),
              ],
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
                      leading: CircleAvatar(
                        radius: 10,
                        backgroundColor: Color(mine[i].colorArgb),
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static int _smartOrder(String id) {
    return switch (id) {
      'smart.today' => 0,
      'smart.scheduled' => 1,
      'smart.all' => 2,
      'smart.flagged' => 3,
      'smart.urgent' => 4,
      'smart.completed' => 5,
      _ => 9,
    };
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
                      repo.toggleCompleted(items[i].id),
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
        backgroundColor: Color(0xFFF2F2F7),
        body: Center(child: Text('列表不存在')),
      );
    }
    return ListContentPane(
      list: list,
      onSelectItem: onSelectItem,
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

class _SmartCard extends StatelessWidget {
  const _SmartCard({required this.list, required this.onTap});

  final ReminderList list;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: 2),
                  Icon(
                    _icon(list.id),
                    color: const Color(0xFF007AFF),
                    size: 22,
                  ),
                  const Spacer(),
                  Text(
                    '${list.itemCount}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                list.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(String id) {
    return switch (id) {
      'smart.today' => Icons.today_outlined,
      'smart.scheduled' => Icons.calendar_today_outlined,
      'smart.all' => Icons.inbox_outlined,
      'smart.flagged' => Icons.flag_outlined,
      'smart.urgent' => Icons.warning_amber_outlined,
      'smart.completed' => Icons.check_circle_outline,
      _ => Icons.list,
    };
  }
}

/// 中等二栏：侧栏 | 列表内容（线框 Pad；侧栏可隐藏铺满主区）。
class _TwoPane extends ConsumerWidget {
  const _TwoPane({
    required this.lists,
    required this.openListId,
    required this.onOpenList,
    this.onSelectItem,
  });

  final List<ReminderList> lists;
  final String? openListId;
  final ValueChanged<String>? onOpenList;
  final ValueChanged<ReminderItem>? onSelectItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = lists.where((e) => e.id == openListId).firstOrNull;
    final sidebarVisible = ref.watch(sidebarVisibleProvider);
    return Row(
      children: [
        if (sidebarVisible) ...[
          SizedBox(
            width: 280,
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
              onOpenSettings: () => showTaskSettingsSheet(context),
            ),
          ),
          const VerticalDivider(width: 1),
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
  });

  final List<ReminderList> lists;
  final String? openListId;
  final String? selectedItemId;
  final ValueChanged<String>? onOpenList;
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

    return Row(
      children: [
        if (sidebarVisible) ...[
          SizedBox(
            width: 240,
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
              onOpenSettings: () => showTaskSettingsSheet(context),
            ),
          ),
          const VerticalDivider(width: 1),
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
          const VerticalDivider(width: 1),
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
  });

  final ReminderList list;
  final ValueChanged<ReminderItem>? onSelectItem;

  /// 紧凑端 AppBar 左侧返回（如「‹ 列表」）；null 时用系统默认（或无 leading）。
  final Widget? leading;

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

  /// 分区（线框「分区一 ∨」）：带 dueAt 顶层条目按日桶，其余进「无日期」。
  /// 保序：沿用 items 自带排序（sortOrder asc, id asc）。
  Map<String, List<ReminderItem>> _buildSections(
    List<ReminderItem> topLevel,
  ) {
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
    final row = ReminderRow(
      item: item,
      onToggleCompleted: () => repo.toggleCompleted(item.id),
      onToggleFlagged: () => repo.toggleFlagged(item.id),
      onTap: () => widget.onSelectItem?.call(item),
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
              dense: true,
              onToggleCompleted: () => repo.toggleCompleted(sub.id),
              onToggleFlagged: () => repo.toggleFlagged(sub.id),
            ),
          ),
      ],
    );
  }

  Future<void> _submitDraft() async {
    final title = _draftController.text.trim();
    if (title.isEmpty) return; // 空标题不落库
    final repo = ref.read(reminderRepositoryProvider);
    // TODO(reminders-parity): 智能视图内的新建提醒应引导选择目标列表（P1）
    await repo.upsertItem(
      ReminderItem(
        id: newReminderId(),
        listId: _isSmartView ? 'list.personal' : widget.list.id,
        title: title,
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
        automaticallyImplyLeading: widget.leading == null,
        leading: widget.leading,
        leadingWidth: widget.leading == null ? null : 96,
        title: Text(widget.list.title),
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
                  hintText: '搜索提醒事项…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF2F2F7),
                ),
              ),
            ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (items) {
          if (query.trim().isNotEmpty && items.isEmpty) {
            return const Center(child: Text('无匹配结果'));
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
          final sections = _buildSections(topLevel);
          final rows = <Widget>[
            for (final entry in sections.entries) ...[
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
            if (_showDraft)
              _DraftRow(
                controller: _draftController,
                onSubmit: _submitDraft,
                onCancel: () {
                  _draftController.clear();
                  setState(() => _showDraft = false);
                },
              ),
          ];

          return Column(
            children: [
              if (!_isTrashView)
                _ListHeaderToolbar(
                remainingCount: remainingCount,
                doneCount: doneCount,
                onClearCompleted: doneCount == 0
                    ? null
                    : () => _clearCompleted(
                          all
                              .where((e) =>
                                  e.isCompleted && e.parentId == null)
                              .map((e) => e.id)
                              .toList(growable: false),
                        ),
              ),
              Expanded(
                child: ListView(children: rows),
              ),
            ],
          );
        },
      ),
      // 底部工具条：iOS 提醒事项式「＋ 新提醒」（对齐线框；禁用 FAB）；
      // 最近删除视图无新建入口（Apple 口径）
      bottomNavigationBar: _isTrashView
          ? null
          : BottomAppBar(
        elevation: 0,
        child: Row(
          children: [
            TextButton.icon(
              onPressed: _openNewItemDialog,
              icon: const Icon(Icons.add, color: Color(0xFF007AFF)),
              label: const Text('新提醒',
                  style: TextStyle(color: Color(0xFF007AFF))),
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

/// 列表头工具行（线框图2 主列表头：大数字 + 显示/排序/清除）。
class _ListHeaderToolbar extends ConsumerWidget {
  const _ListHeaderToolbar({
    required this.remainingCount,
    required this.doneCount,
    this.onClearCompleted,
  });

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
    return Padding(
      key: const ValueKey('list_header_toolbar'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 图2：大数字（未完成数）
              Text(
                '$remainingCount',
                key: const ValueKey('remaining_count'),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF007AFF),
                ),
              ),
              const Spacer(),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(showCompleted ? '显示 ✓' : '显示',
                          style:
                              const TextStyle(fontSize: 13, color: Color(0xFF007AFF))),
                      const Icon(Icons.arrow_drop_down,
                          size: 16, color: Color(0xFF007AFF)),
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
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('排序',
                          style:
                              TextStyle(fontSize: 13, color: Color(0xFF007AFF))),
                      Icon(Icons.arrow_drop_down,
                          size: 16, color: Color(0xFF007AFF)),
                    ],
                  ),
                ),
              ),
              // 清除（已完成 > 0 才可用）
              TextButton(
                key: const ValueKey('clear_completed'),
                onPressed: onClearCompleted,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('清除', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          Text(
            doneCount > 0 ? '$doneCount 项完成' : '',
            key: const ValueKey('done_count'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
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
