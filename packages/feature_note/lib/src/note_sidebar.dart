import 'package:flutter/material.dart';
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
        ListTile(
          key: const ValueKey('note_sidebar_all'),
          leading: const Icon(Icons.all_inbox_outlined),
          title: const Text('所有备忘录'),
          selected: selectedId == null,
          onTap: () =>
              ref.read(selectedNoteFolderIdProvider.notifier).select(null),
        ),
        for (final root in roots) ...[
          _folderTile(context, ref, root, selectedId, 0),
          for (final child in folders
              .where((f) => f.parentId == root.id)
              .toList()
            ..sort(_compareFolders))
            _folderTile(context, ref, child, selectedId, 1),
        ],
      ],
    );
  }

  Widget _folderTile(BuildContext context, WidgetRef ref, NoteFolder folder,
      String? selectedId, int depth) {
    return ListTile(
      key: ValueKey('note_sidebar_${folder.id}'),
      contentPadding: EdgeInsetsDirectional.only(start: 16.0 + depth * 16, end: 16),
      leading: Icon(folder.smart ? Icons.filter_list : Icons.folder_outlined),
      title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selectedId == folder.id,
      onTap: () => ref
          .read(selectedNoteFolderIdProvider.notifier)
          .select(folder.id),
    );
  }

  static int _compareFolders(NoteFolder a, NoteFolder b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
  }
}
