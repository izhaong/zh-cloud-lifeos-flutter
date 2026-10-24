import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../providers.dart';

/// iPad/macOS 左侧栏：智能列表 + 标签浏览器 + 我的列表 + 底部操作区
/// （添加列表 / 隐藏侧栏 / 设置；对齐线框 Pad端与客户端画板）。
///
/// 布局无关的纯内容组件；选中态由外部路由/状态驱动；
/// 底部动作由宿主注入回调（设置面板等 UI 态不放路由）。
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

    // 分组渲染（TC-UI-118）：groupName 相邻同组出折叠头；null 平铺
    final groupedEntries = <Widget>[];
    final flat = <Widget>[];
    String? lastGroup;
    for (final list in mine) {
      final group = list.groupName;
      if (group != null && group != lastGroup) {
        final groupLists =
            mine.where((e) => e.groupName == group).toList();
        final groupCount =
            groupLists.fold<int>(0, (sum, e) => sum + e.itemCount);
        groupedEntries.add(_GroupHeader(
          key: ValueKey('group_$group'),
          title: group,
          count: groupCount,
          collapsed: _collapsedGroups.contains(group),
          onToggle: () => setState(() {
            if (!_collapsedGroups.remove(group)) {
              _collapsedGroups.add(group);
            }
          }),
        ));
      }
      lastGroup = group;
      final tile = _SidebarTile(
        list: list,
        selected: list.id == widget.selectedListId,
        onTap: () => widget.onSelect(list),
      );
      if (group != null && _collapsedGroups.contains(group)) {
        continue; // 折叠组不渲染行
      }
      (group != null ? groupedEntries : flat).add(tile);
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
      color: const Color(0xFFF2F2F7),
      child: Column(
        children: [
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
          // 底部操作区（线框：添加列表 / 隐藏侧栏 / 设置）
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                if (widget.onAddList != null)
                  Expanded(
                    child: _SidebarAction(
                      key: const ValueKey('sidebar_add_list'),
                      icon: CupertinoIcons.add,
                      label: '添加列表',
                      onTap: widget.onAddList!,
                    ),
                  ),
                if (widget.onToggleSidebar != null)
                  Expanded(
                    child: _SidebarAction(
                      key: const ValueKey('sidebar_toggle'),
                      icon: CupertinoIcons.sidebar_left,
                      label: '隐藏侧栏',
                      onTap: widget.onToggleSidebar!,
                    ),
                  ),
                if (widget.onOpenSettings != null)
                  Expanded(
                    child: _SidebarAction(
                      key: const ValueKey('sidebar_settings'),
                      icon: CupertinoIcons.gear,
                      label: '设置',
                      onTap: widget.onOpenSettings!,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarAction extends StatelessWidget {
  const _SidebarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF007AFF)),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF007AFF),
              ),
            ),
          ],
        ),
      ),
    );
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
      trailing: list.itemCount > 0
          ? Text(
              '${list.itemCount}',
              style: const TextStyle(color: Color(0xFF8E8E93)),
            )
          : null,
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
