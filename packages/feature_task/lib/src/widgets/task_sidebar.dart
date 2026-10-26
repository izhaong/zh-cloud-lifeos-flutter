import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../design/life_tokens.dart';
import '../providers.dart';
import 'smart_list_card.dart';

/// Apple Reminders 桌面侧栏（参考图 2）：
/// 顶部工具条 + 2 列彩色智能卡 + 建议列表 + 我的列表 + 标签 + 最近删除。
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
  static const _builtinSmartIds = {
    'smart.today',
    'smart.scheduled',
    'smart.all',
    'smart.flagged',
    'smart.urgent',
    'smart.completed',
    'smart.assigned',
  };
  final _collapsedGroups = <String>{};

  @override
  Widget build(BuildContext context) {
    final allSmart =
        widget.lists.where((e) => e.isSmart).toList(growable: false);
    final smart =
        allSmart.where((e) => _builtinSmartIds.contains(e.id)).toList();
    final customSmart = allSmart.where(
      (e) => !_builtinSmartIds.contains(e.id) && e.id != 'smart.trash',
    );
    final trash = allSmart.where((e) => e.id == 'smart.trash').firstOrNull;
    final mine =
        widget.lists.where((e) => !e.isSmart).toList(growable: false);
    final hasGrocery =
        mine.any((e) => e.listType == ReminderListType.grocery);

    // 分组渲染（TC-UI-118）：先按 groupName 聚合（同名唯一组头，
    // 组内按原序；null 平铺）——交错 B,A,B 不重复出「B」头。
    final groupedEntries = <Widget>[];
    final flat = <Widget>[];
    final groupOrder = <String>[];
    final groupLists = <String, List<ReminderList>>{};
    for (final list in mine) {
      final g = list.groupName;
      if (g == null) {
        flat.add(_MyListRow(
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
          groupedEntries.add(_MyListRow(
            list: list,
            selected: list.id == widget.selectedListId,
            onTap: () => widget.onSelect(list),
          ));
        }
      }
    }

    // 标签浏览器（TC-UI-117）：全部未删条目的去重标签；
    // 点选 = 写全局搜索词（过滤管线已按标题/备注/标签匹配）。
    final tagsAsync = ref.watch(itemsForListProvider(null));
    final tags = (tagsAsync.asData?.value ?? const <ReminderItem>[])
        .expand((e) => e.tags)
        .toSet()
        .toList(growable: false)
      ..sort();

    return Material(
      color: LifeTokens.sidebarBg,
      child: Column(
        children: [
          // 顶部工具条（图2：新建列表｜隐藏侧栏｜⚙设置）
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
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                if (smart.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: LifeTokens.cardGap,
                        crossAxisSpacing: LifeTokens.cardGap,
                        mainAxisExtent: 60,
                      ),
                      itemCount: smart.length,
                      itemBuilder: (context, i) => SmartListCard(
                        list: smart[i],
                        selected: smart[i].id == widget.selectedListId,
                        onTap: () => widget.onSelect(smart[i]),
                      ),
                    ),
                  ),
                if (!hasGrocery && mine.isNotEmpty)
                  _SuggestedListRow(
                    onTap: () {
                      final id =
                          'list.grocery.${DateTime.now().millisecondsSinceEpoch}';
                      ref.read(reminderRepositoryProvider).upsertList(
                            ReminderList.createGroceryList(
                              id: id,
                              title: '日常采购',
                            ),
                          );
                    },
                  ),
                if (mine.isNotEmpty || customSmart.isNotEmpty) ...[
                  const _SectionLabel('我的列表'),
                  ...groupedEntries,
                  ...flat,
                  for (final list in customSmart)
                    _MyListRow(
                      list: list,
                      selected: list.id == widget.selectedListId,
                      onTap: () => widget.onSelect(list),
                      customSmart: true,
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
                if (trash != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    child: _MyListRow(
                      list: trash,
                      selected: trash.id == widget.selectedListId,
                      onTap: () => widget.onSelect(trash),
                      isTrash: true,
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
        child: Icon(icon, size: 18, color: LifeTokens.systemBlue),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: LifeTokens.labelSecondary,
        ),
      ),
    );
  }
}

/// 我的列表行：24px 彩色圆角图标 + 标题 + 计数。
class _MyListRow extends StatelessWidget {
  const _MyListRow({
    required this.list,
    required this.selected,
    required this.onTap,
    this.customSmart = false,
    this.isTrash = false,
  });

  final ReminderList list;
  final bool selected;
  final VoidCallback onTap;
  final bool customSmart;
  final bool isTrash;

  @override
  Widget build(BuildContext context) {
    final color = isTrash ? LifeTokens.labelSecondary : Color(list.colorArgb);
    final icon = isTrash
        ? CupertinoIcons.trash
        : customSmart
            ? CupertinoIcons.sparkles
            : list.listType == ReminderListType.grocery
                ? CupertinoIcons.cart
                : CupertinoIcons.list_bullet;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected
            ? LifeTokens.systemBlue.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('my_list_${list.id}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(LifeTokens.radiusListIcon),
                  ),
                  child: Icon(icon, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    list.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: LifeTokens.labelPrimary,
                    ),
                  ),
                ),
                Text(
                  '${list.itemCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: LifeTokens.labelSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 建议列表（参考图「建议列表：日常采购 ＋」）；点击创建真实 grocery 列表。
class _SuggestedListRow extends StatelessWidget {
  const _SuggestedListRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('suggested_grocery'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            child: Row(
              children: [
                const Icon(CupertinoIcons.cart_fill,
                    color: LifeTokens.systemGreen, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '建议列表：日常采购',
                    style: TextStyle(
                      fontSize: 13,
                      color: LifeTokens.labelPrimary,
                    ),
                  ),
                ),
                InkWell(
                  key: const ValueKey('suggested_grocery_add'),
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(CupertinoIcons.add_circled_solid,
                        color: LifeTokens.systemGreen, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                color: LifeTokens.labelSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  color: LifeTokens.labelSecondary,
                ),
              ),
            ],
            const Spacer(),
            Icon(
              collapsed
                  ? CupertinoIcons.chevron_down
                  : CupertinoIcons.chevron_up,
              size: 14,
              color: LifeTokens.labelSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
