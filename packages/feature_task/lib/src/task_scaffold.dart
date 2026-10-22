import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'providers.dart';
import 'widgets/new_list_dialog.dart';
import 'widgets/reminder_detail_pane.dart';
import 'widgets/reminder_row.dart';
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
  });

  /// 紧凑端首页概览（列表首页）：智能列表卡片 + 我的列表。
  final String? openListId;

  /// 三栏第三列选中的提醒 id；空 = 不显示详情栏。
  final String? selectedItemId;

  /// 点开列表的回调（紧凑端由壳层路由推栈）。
  final ValueChanged<String>? onOpenList;

  /// 点开提醒条目的回调（紧凑端推详情模态）。
  final ValueChanged<ReminderItem>? onSelectItem;

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
                )
              : _CompactListPane(
                  lists: lists,
                  openListId: openListId!,
                  onSelectItem: onSelectItem,
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
class _CompactPane extends ConsumerWidget {
  const _CompactPane({
    required this.lists,
    required this.onOpenList,
  });

  final List<ReminderList> lists;
  final ValueChanged<String>? onOpenList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smart = lists.where((e) => e.isSmart).toList(growable: false);
    final mine = lists.where((e) => !e.isSmart).toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(title: const Text('提醒事项')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              for (final list in smart
                ..sort((a, b) => _smartOrder(a.id).compareTo(_smartOrder(b.id))))
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
                    trailing: Text('${mine[i].itemCount}'),
                    onTap: () => onOpenList?.call(mine[i].id),
                  ),
                ],
                const Divider(height: 1, indent: 52),
                // 「添加列表」入口（对齐线框：我的列表区底部）
                ListTile(
                  leading: const Icon(CupertinoIcons.add,
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
      ),
    );
  }

  static int _smartOrder(String id) {
    return switch (id) {
      'smart.today' => 0,
      'smart.scheduled' => 1,
      'smart.all' => 2,
      'smart.flagged' => 3,
      _ => 9,
    };
  }
}



/// 紧凑端全屏单列表（栈导航推入后）：带返回的列表内容页。
class _CompactListPane extends StatelessWidget {
  const _CompactListPane({
    required this.lists,
    required this.openListId,
    this.onSelectItem,
  });

  final List<ReminderList> lists;
  final String openListId;
  final ValueChanged<ReminderItem>? onSelectItem;

  @override
  Widget build(BuildContext context) {
    final list = lists.where((e) => e.id == openListId).firstOrNull;
    if (list == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF2F2F7),
        body: Center(child: Text('列表不存在')),
      );
    }
    return _WithBackButton(
      child: ListContentPane(list: list, onSelectItem: onSelectItem),
    );
  }
}

/// 紧凑端列表页外层：推入返回按钮（对齐提醒事项「‹ 列表」）。
class _WithBackButton extends StatelessWidget {
  const _WithBackButton({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
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
      _ => Icons.list,
    };
  }
}

/// 中等二栏：侧栏 | 列表内容。
class _TwoPane extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final current = lists.where((e) => e.id == openListId).firstOrNull;
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: TaskSidebar(
            lists: lists,
            selectedListId: openListId,
            onSelect: (l) => onOpenList?.call(l.id),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: current == null
              ? const _EmptyOverview()
              : ListContentPane(list: current, onSelectItem: onSelectItem),
        ),
      ],
    );
  }
}

/// 展开三栏：侧栏 | 列表内容 | 详细信息。
class _ThreePane extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final current = lists.where((e) => e.id == openListId).firstOrNull;
    final itemsAsync = ref.watch(itemsForListProvider(openListId));
    final selected = itemsAsync.maybeWhen(
      data: (items) =>
          items.where((e) => e.id == selectedItemId).firstOrNull,
      orElse: () => null,
    );

    return Row(
      children: [
        SizedBox(
          width: 240,
          child: TaskSidebar(
            lists: lists,
            selectedListId: openListId,
            onSelect: (l) => onOpenList?.call(l.id),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: current == null
              ? const _EmptyOverview()
              : ListContentPane(list: current, onSelectItem: onSelectItem),
        ),
        if (selected != null) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            width: 320,
            child: ReminderDetailPane(
              item: selected,
              onSaved: (updated) =>
                  ref.read(reminderRepositoryProvider).upsertItem(updated),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyOverview extends StatelessWidget {
  const _EmptyOverview();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: Text('选择一个列表')),
    );
  }
}

/// 列表内容区（布局无关）：条目行 + 完成态/旗标即时回写 + 新建提醒草稿行 +
/// 底部工具条（iOS 提醒事项式「＋ 新提醒」；智能视图隐藏）。
class ListContentPane extends ConsumerStatefulWidget {
  const ListContentPane({super.key, required this.list, this.onSelectItem});

  final ReminderList list;
  final ValueChanged<ReminderItem>? onSelectItem;

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
    final repo = ref.watch(reminderRepositoryProvider);
    final query = ref.watch(searchQueryProvider);
    final isPane = WindowSizeClass.fromWidth(
      MediaQuery.of(context).size.width,
    ).isPaneLayout;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
          final topLevel = items.where((e) {
            if (e.parentId == null) return true;
            // 孤儿（父不在结果集）或自环 → 按顶层渲染
            return !itemsById.containsKey(e.parentId) || e.parentId == e.id;
          }).toList(growable: false);
          final subtasksByParent = <String, List<ReminderItem>>{};
          for (final e in items) {
            if (e.parentId != null &&
                itemsById.containsKey(e.parentId) &&
                e.parentId != e.id) {
              subtasksByParent.putIfAbsent(e.parentId!, () => []).add(e);
            }
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: topLevel.length + (_showDraft ? 1 : 0),
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (context, index) {
                    if (_showDraft && index == topLevel.length) {
                      return _DraftRow(
                        controller: _draftController,
                        onSubmit: _submitDraft,
                        onCancel: () {
                          _draftController.clear();
                          setState(() => _showDraft = false);
                        },
                      );
                    }
                    final item = topLevel[index];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReminderRow(
                          item: item,
                          onToggleCompleted: () =>
                              repo.toggleCompleted(item.id),
                          onToggleFlagged: () =>
                              repo.toggleFlagged(item.id),
                          onTap: () => widget.onSelectItem?.call(item),
                        ),
                        for (final sub in subtasksByParent[item.id] ??
                            const <ReminderItem>[])
                          Padding(
                            padding: const EdgeInsets.only(left: 40),
                            child: ReminderRow(
                              item: sub,
                              dense: true,
                              onToggleCompleted: () =>
                                  repo.toggleCompleted(sub.id),
                              onToggleFlagged: () =>
                                  repo.toggleFlagged(sub.id),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      // 底部工具条：iOS 提醒事项式「＋ 新提醒」（对齐线框；禁用 FAB）
      bottomNavigationBar: BottomAppBar(
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
