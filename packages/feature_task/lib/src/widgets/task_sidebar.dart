import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../providers.dart';

/// iPad/macOS 左侧栏：**顶部工具条（新建列表｜隐藏侧栏｜设置，图2 口径）**
/// + 智能列表 + 标签浏览器 + 我的列表。
///
/// 布局无关的纯内容组件；选中态由外部路由/状态驱动；
/// 工具条动作由宿主注入回调（设置面板等 UI 态不放路由）。
class TaskSidebar extends ConsumerStatefulWidget {
  const TaskSidebar({
    super.key,
    required this.lists,
    required this.selectedListId,
    required this.onSelect,
    this.onAddList,
    this.onToggleSidebar,
    this.onOpenSettings,
  });

  final List<ReminderList> lists;
  final String? selectedListId;
  final ValueChanged<ReminderList> onSelect;
  final VoidCallback? onAddList;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<TaskSidebar> createState() => _TaskSidebarState();
}

class _TaskSidebarState extends ConsumerState<TaskSidebar> {
  final _collapsedGroups = <String>{};

  @override
  Widget build(BuildContext context) {
    final smart =
        widget.lists.where((e) => e.isSmart).toList(growable: false);
    final mine =
        widget.lists.where((e) => !e.isSmart).toList(growable: false);

    // 分组渲染（TC-UI-118）：**先按 groupName 聚合**（同名唯一组头，
    // 组内按原序；null 平铺）——交错 B,A,B 不会重复出「B」头（cursor PR#14 非阻断2）
    final groupedEntries = <Widget>[];
    final flat = <Widget>[];
    final groupOrder = <String>[];
    final groupLists = <String, List<ReminderList>>{};
    for (final list in mine) {
      final g = list.groupName;
      if (g == null) {
        flat.add(_SidebarTile(
          list: list,
          selected: list.id == widget.selectedListId,
          onTap: () => widget.onSelect(list),
        ));
        continue;
      }
      if (!groupLists.containsKey(g)) {
        groupOrder.add(g);
        groupLists[g] = [];
      }
      groupLists[g]!.add(list);
    }
    for (final g in groupOrder) {
      final listsInGroup = groupLists[g]!;
      final groupCount =
          listsInGroup.fold<int>(0, (sum, e) => sum + e.itemCount);
      groupedEntries.add(_GroupHeader(
        key: ValueKey('group_$g'),
        title: g,
        count: groupCount,
        collapsed: _collapsedGroups.contains(g),
        onToggle: () => setState(() {
          if (!_collapsedGroups.remove(g)) {
            _collapsedGroups.add(g);
          }
        }),
      ));
      if (!_collapsedGroups.contains(g)) {
        for (final list in listsInGroup) {
          groupedEntries.add(_SidebarTile(
            list: list,
            selected: list.id == widget.selectedListId,
            onTap: () => widget.onSelect(list),
          ));
        }
      }
    }
    // 标签浏览器（TC-UI-117）：全部未删条目的去重标签；
    // 点选 = 写全局搜索词（过滤管线已按标题/备注/标签匹配）
    final tagsAsync = ref.watch(itemsForListProvider(null));
    final tags = (tagsAsync.asData?.value ?? const <ReminderItem>[])
        .expand((e) => e.tags)
        .toSet()
        .toList(growable: false)
      ..sort();

    return Material(
      color: const Color(0xFFECECF1),
      child: Column(
        children: [
              // 顶部工具条（图2：新建列表｜隐藏侧栏｜⚙设置——小图标横排）
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Row(
                  children: [
                    _TopIcon(
                      key: const ValueKey('sidebar_add_list'),
                      icon: CupertinoIcons.add,
                      tooltip: '新建列表',
                      onTap: widget.onAddList ?? () {},
                    ),
                    const SizedBox(width: 12),
                    _TopIcon(
                      key: const ValueKey('sidebar_toggle'),
                      icon: CupertinoIcons.sidebar_left,
                      tooltip: '隐藏侧栏',
                      onTap: widget.onToggleSidebar ?? () {},
                    ),
                    const Spacer(),
                    _TopIcon(
                      key: const ValueKey('sidebar_settings'),
                      icon: CupertinoIcons.gear,
                      tooltip: '设置',
                      onTap: widget.onOpenSettings ?? () {},
                    ),
                  ],
                ),
              ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (smart.isNotEmpty) ...[
                  const _SectionLabel('智能列表'),
                  for (final list in smart)
                    _SidebarTile(
                      list: list,
                      selected: list.id == widget.selectedListId,
                      onTap: () => widget.onSelect(list),
                    ),
                ],
                if (tags.isNotEmpty) ...[
                  const _SectionLabel('标签'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tags)
                          ActionChip(
                            key: ValueKey('tag_chip_$tag'),
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => ref
                                .read(searchQueryProvider.notifier)
                                .set(tag),
                          ),
                      ],
                    ),
                  ),
                ],
                if (mine.isNotEmpty) ...[
                  const _SectionLabel('我的列表'),
                  ...groupedEntries,
                  ...flat,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: const Color(0xFF007AFF)),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8E8E93),
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.list,
    required this.selected,
    required this.onTap,
  });

  final ReminderList list;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: list.isSmart
          ? Icon(
              _smartIcon(list.id),
              size: 20,
              color: const Color(0xFF007AFF),
            )
          : CircleAvatar(
              radius: 8,
              backgroundColor: Color(list.colorArgb),
            ),
      title: Text(
        list.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      // Apple 侧栏口径（cursor 实机图评）：0 也显示计数（金标准今天=1、旗标=0 均可见）
      trailing: Text(
        '${list.itemCount}',
        style: const TextStyle(color: Color(0xFF8E8E93)),
      ),
      selected: selected,
      selectedTileColor: const Color(0xFFD1D1D6),
      onTap: onTap,
    );
  }

  static IconData _smartIcon(String id) {
    return switch (id) {
      'smart.today' => CupertinoIcons.today,
      'smart.scheduled' => CupertinoIcons.calendar,
      'smart.all' => CupertinoIcons.tray_full,
      'smart.flagged' => CupertinoIcons.flag_fill,
      'smart.urgent' => CupertinoIcons.exclamationmark_triangle_fill,
      'smart.completed' => CupertinoIcons.checkmark_alt_circle,
      'smart.trash' => CupertinoIcons.trash,
      _ => CupertinoIcons.list_bullet,
    };
  }
}

/// 分组折叠头（TC-UI-118）：组名 + 组内计数 + 折叠箭头。
/// 负向门禁：本平台无账户概念，组名一律来自用户数据（禁 iCloud/Outlook 硬编码）。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    super.key,
    required this.title,
    required this.count,
    required this.collapsed,
    required this.onToggle,
  });

  final String title;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
            ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
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
