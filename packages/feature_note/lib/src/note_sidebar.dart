import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'providers.dart';

/// 文件夹侧栏（F-04；契约 §5、guide/iphone/01）。
///
/// 树形展示普通文件夹与智能文件夹；点选把 [selectedNoteFolderIdProvider]
/// 指向该文件夹，主区笔记列表随之过滤。「所有备忘录」= 全部未删除笔记。
class NoteSidebar extends ConsumerWidget {
  const NoteSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders =
        ref.watch(noteFoldersProvider).value ?? const <NoteFolder>[];
    final selectedId = ref.watch(selectedNoteFolderIdProvider);
    final roots = folders.where((f) => f.parentId == null).toList()
      ..sort(_compareFolders);

    return ListView(
      key: const ValueKey('note_sidebar'),
      children: [
        _folderTile(
          context,
          ref,
          key: const ValueKey('note_sidebar_all'),
          name: '所有备忘录',
          smart: false,
          selected: selectedId == null,
          depth: 0,
          onTap: () =>
              ref.read(selectedNoteFolderIdProvider.notifier).select(null),
        ),
        for (final root in roots) ...[
          _folderTile(
            context,
            ref,
            key: ValueKey('note_sidebar_${root.id}'),
            name: root.name,
            smart: root.smart,
            selected: selectedId == root.id,
            depth: 0,
            onTap: () =>
                ref.read(selectedNoteFolderIdProvider.notifier).select(root.id),
          ),
          for (final child in folders
              .where((f) => f.parentId == root.id)
              .toList()
            ..sort(_compareFolders))
            _folderTile(
              context,
              ref,
              key: ValueKey('note_sidebar_${child.id}'),
              name: child.name,
              smart: child.smart,
              selected: selectedId == child.id,
              depth: 1,
              onTap: () => ref
                  .read(selectedNoteFolderIdProvider.notifier)
                  .select(child.id),
            ),
        ],
      ],
    );
  }

  Widget _folderTile(
    BuildContext context,
    WidgetRef ref, {
    required Key key,
    required String name,
    required bool smart,
    required bool selected,
    required int depth,
    required VoidCallback onTap,
  }) {
    final color = CupertinoDynamicColor.withBrightness(
      color: CupertinoColors.label.color,
      darkColor: CupertinoColors.label.darkColor,
    );
    return CupertinoListTile(
      key: key,
      padding: EdgeInsetsDirectional.only(start: 16.0 + depth * 16, end: 16),
      leading: Icon(
        smart ? CupertinoIcons.slider_horizontal_3 : CupertinoIcons.folder,
        size: 20,
        color: selected ? CupertinoColors.systemBlue : null,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? CupertinoColors.systemBlue : color,
        ),
      ),
      onTap: onTap,
    );
  }

  static int _compareFolders(NoteFolder a, NoteFolder b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
  }
}
