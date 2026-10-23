import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// iPad/macOS 左侧栏：智能列表 + 我的列表 + 底部操作区
/// （添加列表 / 隐藏侧栏 / 设置；对齐线框 Pad端与客户端画板）。
///
/// 布局无关的纯内容组件；选中态由外部路由/状态驱动；
/// 底部动作由宿主注入回调（设置面板等 UI 态不放路由）。
class TaskSidebar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final smart = lists.where((e) => e.isSmart).toList(growable: false);
    final mine = lists.where((e) => !e.isSmart).toList(growable: false);

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
                      selected: list.id == selectedListId,
                      onTap: () => onSelect(list),
                    ),
                ],
                if (mine.isNotEmpty) ...[
                  const _SectionLabel('我的列表'),
                  for (final list in mine)
                    _SidebarTile(
                      list: list,
                      selected: list.id == selectedListId,
                      onTap: () => onSelect(list),
                    ),
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
                if (onAddList != null)
                  Expanded(
                    child: _SidebarAction(
                      key: const ValueKey('sidebar_add_list'),
                      icon: CupertinoIcons.add,
                      label: '添加列表',
                      onTap: onAddList!,
                    ),
                  ),
                if (onToggleSidebar != null)
                  Expanded(
                    child: _SidebarAction(
                      key: const ValueKey('sidebar_toggle'),
                      icon: CupertinoIcons.sidebar_left,
                      label: '隐藏侧栏',
                      onTap: onToggleSidebar!,
                    ),
                  ),
                if (onOpenSettings != null)
                  Expanded(
                    child: _SidebarAction(
                      key: const ValueKey('sidebar_settings'),
                      icon: CupertinoIcons.gear,
                      label: '设置',
                      onTap: onOpenSettings!,
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
      _ => CupertinoIcons.list_bullet,
    };
  }
}
