import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shell_providers.dart';
import 'app_registry.dart';

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
    setState(() {}); // 触发依赖偏好流的重绘
  }

  void _add(String id) {
    final cur = ref.read(pinnedTabsServiceProvider).read();
    ref
        .read(pinnedTabsServiceProvider)
        .write([...cur, id]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(pinnedTabsServiceProvider);
    final pinnedIds = service.read();
    final pinnedSet = pinnedIds.toSet();
    final badges = ref.watch(shellBadgeCountsProvider);

    final pinned =
        pinnedIds.map(appById).toList(growable: false);
    final unpinned = installedApps
        .where((e) => !pinnedSet.contains(e.id))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('更多'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _editing = !_editing),
            child: Text(_editing ? '完成' : '编辑'),
          ),
        ],
      ),
      body: ListView(
        children: [
          if (_editing) ...[
            const _SectionLabel('已固定到 Tab（拖拽排序）'),
            // 拖拽仅作用于固定区；「更多」不在此区（恒最右，不可编辑）
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: pinned.length,
              // onReorderItem 已为调用方调整 newIndex（移除项偏移）
              onReorderItem: (oldIndex, newIndex) {
                final cur = [...ref
                    .read(pinnedTabsServiceProvider)
                    .read()];
                final moved = cur.removeAt(oldIndex);
                cur.insert(newIndex.clamp(0, cur.length), moved);
                ref.read(pinnedTabsServiceProvider).write(cur);
                setState(() {});
              },
              itemBuilder: (context, index) {
                final app = pinned[index];
                return ListTile(
                  key: ValueKey('pinned_${app.id}'),
                  leading: Icon(app.icon),
                  title: Text(app.title),
                  subtitle: app.isPlaceholder
                      ? const Text('占位 · feature_* 待拆入')
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                      IconButton(
                        key: ValueKey('unpin_${app.id}'),
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _remove(app.id),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (unpinned.isNotEmpty) ...[
              const _SectionLabel('未固定（＋ 加回 Tab）'),
              for (final app in unpinned)
                ListTile(
                  key: ValueKey('unpinned_${app.id}'),
                  leading: Icon(app.icon),
                  title: Text(app.title),
                  subtitle: app.isPlaceholder
                      ? const Text('占位 · feature_* 待拆入')
                      : null,
                  trailing: IconButton(
                    key: ValueKey('pin_${app.id}'),
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _add(app.id),
                  ),
                ),
            ],
          ] else ...[
            const _SectionLabel('全部已装应用'),
            // 展示态：已固定应用无角标（其未读在 Tab 上），未固定显示角标
            for (final app in installedApps)
              _AppRow(
                app: app,
                badgeCount: pinnedSet.contains(app.id)
                    ? 0
                    : (badges[app.id] ?? 0),
              ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('添加更多应用'),
            subtitle: const Text('打开 LifeOS App Store（H1 目录）'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('目录客户端 Phase 5')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, this.badgeCount = 0});

  final AppEntry app;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(app.icon);
    return ListTile(
      leading: badgeCount > 0
          ? Badge.count(count: badgeCount, child: icon)
          : icon,
      title: Text(app.title),
      subtitle: app.isPlaceholder
          ? const Text('占位 · feature_* 待拆入')
          : const Text('已安装'),
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
