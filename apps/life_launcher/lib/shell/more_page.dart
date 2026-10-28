import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shell_providers.dart';
import 'app_registry.dart';
import 'shell_badge.dart';

/// 「更多」面板：全部已装应用 + 就地编辑（§1.4）。
///
/// - 顶栏「编辑」切换编辑态：行内 −移出/＋加回、拖拽手柄重排（写即生效）
/// - 「更多」自身恒最右不可移除：编辑态不出现 −/手柄
/// - 徽标：未固定应用显示未读角标（已固定的在 Tab 上显示，不重复）
/// - 底部「＋ 添加更多应用」→ 目录（Phase 5 占位）
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _MoreView();
  }
}

class _MoreView extends ConsumerStatefulWidget {
  const _MoreView();

  @override
  ConsumerState<_MoreView> createState() => _MoreViewState();
}

class _MoreViewState extends ConsumerState<_MoreView> {
  bool _editing = false;

  void _remove(String id) {
    final cur = ref.read(pinnedTabsServiceProvider).read();
    ref.read(pinnedTabsServiceProvider).write(
          cur.where((e) => e != id).toList(growable: false),
        );
    setState(() {});
  }

  void _add(String id) {
    final cur = ref.read(pinnedTabsServiceProvider).read();
    ref.read(pinnedTabsServiceProvider).write([...cur, id]);
    setState(() {});
  }

  void _reorder(int oldIndex, int newIndex) {
    final cur = [...ref.read(pinnedTabsServiceProvider).read()];
    final moved = cur.removeAt(oldIndex);
    cur.insert(newIndex.clamp(0, cur.length), moved);
    ref.read(pinnedTabsServiceProvider).write(cur);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(pinnedTabsServiceProvider);
    final pinnedIds = service.read();
    final pinnedSet = pinnedIds.toSet();
    final badges = ref.watch(shellBadgeCountsProvider);

    final pinned = pinnedIds.map(appById).toList(growable: false);
    final unpinned = installedApps
        .where((e) => !pinnedSet.contains(e.id))
        .toList(growable: false);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('更多'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => setState(() => _editing = !_editing),
          child: Text(_editing ? '完成' : '编辑'),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            if (_editing) ...[
              const SliverToBoxAdapter(
                child: _SectionLabel('已固定到 Tab（拖拽排序）'),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverReorderableList(
                  itemCount: pinned.length,
                  onReorderItem: _reorder,
                  itemBuilder: (context, index) {
                    final app = pinned[index];
                    return _PinnedRow(
                      key: ValueKey('pinned_${app.id}'),
                      app: app,
                      index: index,
                      isFirst: index == 0,
                      isLast: index == pinned.length - 1,
                      onRemove: _remove,
                    );
                  },
                ),
              ),
              if (unpinned.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const _SectionLabel('未固定（＋ 加回 Tab）'),
                      CupertinoListSection.insetGrouped(
                        children: [
                          for (final app in unpinned)
                            CupertinoListTile(
                              key: ValueKey('unpinned_${app.id}'),
                              leading: Icon(app.icon),
                              title: Text(app.title),
                              subtitle: app.isPlaceholder
                                  ? const Text('即将推出')
                                  : null,
                              trailing: CupertinoButton(
                                key: ValueKey('pin_${app.id}'),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                onPressed: () => _add(app.id),
                                child: const Icon(
                                  CupertinoIcons.plus_circle,
                                  color: CupertinoColors.systemBlue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ] else
              SliverToBoxAdapter(
                child: CupertinoListSection.insetGrouped(
                  header: const Text('全部已装应用'),
                  children: [
                    for (final app in installedApps)
                      CupertinoListTile(
                        key: ValueKey('app_${app.id}'),
                        leading: Icon(app.icon),
                        title: Text(app.title),
                        subtitle: Text(
                          app.isPlaceholder ? '即将推出' : '已安装',
                        ),
                        trailing: !pinnedSet.contains(app.id) &&
                                (badges[app.id] ?? 0) > 0
                            ? ShellBadge(
                                key: ValueKey('shell_badge_${app.id}'),
                                count: badges[app.id]!,
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: CupertinoListSection.insetGrouped(
                  children: [
                    CupertinoListTile(
                      key: const ValueKey('add_more_apps'),
                      leading: const Icon(CupertinoIcons.plus_circle),
                      title: const Text('添加更多应用'),
                      subtitle: const Text('打开 LifeOS App Store（H1 目录）'),
                      onTap: () => _showCatalogPlaceholder(context),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Future<void> _showCatalogPlaceholder(BuildContext context) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('LifeOS App Store'),
        content: const Text('目录客户端 Phase 5'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }
}

class _PinnedRow extends StatelessWidget {
  const _PinnedRow({
    super.key,
    required this.app,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.onRemove,
  });

  final AppEntry app;
  final int index;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final separator = CupertinoColors.separator.resolveFrom(context);
    const radius = Radius.circular(10);
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: isFirst ? radius : Radius.zero,
        bottom: isLast ? radius : Radius.zero,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          border: isFirst
              ? null
              : Border(top: BorderSide(color: separator, width: 0.5)),
        ),
        child: CupertinoListTile(
          backgroundColor: background,
          leading: Icon(app.icon),
          title: Text(app.title),
          subtitle: app.isPlaceholder
              ? const Text('即将推出')
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(
                  CupertinoIcons.line_horizontal_3,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                key: ValueKey('unpin_${app.id}'),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => onRemove(app.id),
                child: const Icon(
                  CupertinoIcons.minus_circle,
                  color: CupertinoColors.systemRed,
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}
