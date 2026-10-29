import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:app_core/app_core.dart';

import 'logic/default_folder_bootstrap.dart';
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
        // parity#155：Apple 备忘录侧栏可直接「新建文件夹」；此前全仓无入口，
        // 空库下「新建备忘录/快速记录」会被「先新建一个文件夹」挡死。
        CupertinoListTile(
          key: const ValueKey('note_sidebar_new_folder'),
          padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
          leading: const Icon(
            CupertinoIcons.folder_badge_plus,
            size: 20,
            color: CupertinoColors.systemBlue,
          ),
          title: const Text(
            '新建文件夹',
            style: TextStyle(color: CupertinoColors.systemBlue),
          ),
          onTap: () => _createFolder(context, ref),
        ),
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
          for (final child
              in folders.where((f) => f.parentId == root.id).toList()
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

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => LifeAlertDialog(
        title: const Text('新建文件夹'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            key: const ValueKey('note_new_folder_name'),
            controller: controller,
            autofocus: true,
            placeholder: '名称',
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
        ),
        actions: [
          LifeDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          LifeDialogAction(
            key: const ValueKey('note_new_folder_ok'),
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('好'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    final title = (name ?? '').trim();
    if (title.isEmpty) return;
    final repo = ref.read(noteRepositoryProvider);
    final id = await repo.upsertFolder(
      NoteFolder(id: newNoteFolderId(), name: title),
    );
    ref.read(selectedNoteFolderIdProvider.notifier).select(id);
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
    // #371：此前这里手拼 CupertinoDynamicColor.withBrightness(label.color,
    // darkColor: label.darkColor)，再把这个**未解算**的对象塞进 TextStyle(color:)。
    // TextStyle 不像 CupertinoListTile 的默认样式那样自动解算，暗色档会按亮档
    // 黑色绘制 —— 黑底黑字，名称不可见。直接解算即可（label 本身就是动态色）。
    final color = CupertinoColors.label.resolveFrom(context);
    return CupertinoListTile(
      key: key,
      padding: EdgeInsetsDirectional.only(start: 16.0 + depth * 16, end: 16),
      leading: Icon(
        smart ? CupertinoIcons.slider_horizontal_3 : CupertinoIcons.folder,
        size: 20,
        color: selected ? CupertinoColors.systemBlue.resolveFrom(context) : null,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? CupertinoColors.systemBlue.resolveFrom(context) : color,
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
