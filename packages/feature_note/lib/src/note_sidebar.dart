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
///
/// #393 补上 Apple 侧栏另外两件：分节标题（「文件夹」/「标签」）与每行的数量
/// 徽章，并把 [noteTagsProvider] 的标签做成可点选的浏览入口（[selectedNoteTagProvider]）。
class NoteSidebar extends ConsumerWidget {
  const NoteSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders =
        ref.watch(noteFoldersProvider).value ?? const <NoteFolder>[];
    final selectedId = ref.watch(selectedNoteFolderIdProvider);
    final selectedTag = ref.watch(selectedNoteTagProvider);
    final tags = ref.watch(noteTagsProvider).value ?? const <NoteTag>[];
    final counts = ref.watch(noteSidebarCountsProvider).value ??
        const NoteSidebarCounts.empty();
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
        // #393：Apple 侧栏是「分节 + 每行数量」两件事，之前两个都没有——
        // 一列同权重的名字，既看不出层级归属，也看不出每个文件夹里有多少条。
        _sectionHeader(context, keyName: 'note_sidebar_section_folders', title: '文件夹'),
        _folderTile(
          context,
          ref,
          key: const ValueKey('note_sidebar_all'),
          name: '所有备忘录',
          smart: false,
          selected: selectedId == null && selectedTag == null,
          depth: 0,
          count: counts.total,
          countKey: 'note_folder_count_all',
          onTap: () => _selectFolder(ref, null),
        ),
        for (final root in roots) ...[
          _folderTile(
            context,
            ref,
            key: ValueKey('note_sidebar_${root.id}'),
            name: root.name,
            smart: root.smart,
            folder: root,
            selected: selectedId == root.id,
            depth: 0,
            count: root.smart ? null : counts.folderCount(root.id),
            countKey: 'note_folder_count_${root.id}',
            onTap: () => _selectFolder(ref, root.id),
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
              folder: child,
              selected: selectedId == child.id,
              depth: 1,
              count: child.smart ? null : counts.folderCount(child.id),
              countKey: 'note_folder_count_${child.id}',
              onTap: () => _selectFolder(ref, child.id),
            ),
        ],
        // #393：标签区。无标签时整节不摆（Apple 也不给空分区挂标题）；
        // 有标签则每行 = 该标签下的笔记数，点选 = 跨文件夹按标签浏览。
        if (tags.isNotEmpty) ...[
          _sectionHeader(context, keyName: 'note_sidebar_section_tags', title: '标签'),
          for (final tag in tags)
            _tagTile(
              context,
              key: ValueKey('note_sidebar_tag_${tag.name}'),
              name: tag.name,
              selected: selectedTag == tag.name,
              count: counts.tagCount(tag.name),
              countKey: 'note_tag_count_${tag.name}',
              onTap: () => _selectTag(ref, tag.name),
            ),
        ],
      ],
    );
  }

  /// 选中文件夹：同时清掉标签选中（两把高亮只能亮一把，见 providers 注释）。
  void _selectFolder(WidgetRef ref, String? folderId) {
    ref.read(selectedNoteTagProvider.notifier).select(null);
    ref.read(selectedNoteFolderIdProvider.notifier).select(folderId);
  }

  /// 选中标签：清掉文件夹选中；再点同一个标签 = 取消过滤。
  void _selectTag(WidgetRef ref, String tagName) {
    final clearing = ref.read(selectedNoteTagProvider) == tagName;
    ref.read(selectedNoteFolderIdProvider.notifier).select(null);
    ref.read(selectedNoteTagProvider.notifier).select(clearing ? null : tagName);
  }

  /// 分节标题（#393）。文案是「文件夹 / 标签」两节，不引账户体系名称。
  Widget _sectionHeader(
    BuildContext context, {
    required String keyName,
    required String title,
  }) {
    return Padding(
      key: ValueKey(keyName),
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        top: 14,
        bottom: 4,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
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
    ref.read(selectedNoteTagProvider.notifier).select(null);
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
    NoteFolder? folder,
    int? count,
    String? countKey,
  }) {
    // #371：此前这里手拼 CupertinoDynamicColor.withBrightness(label.color,
    // darkColor: label.darkColor)，再把这个**未解算**的对象塞进 TextStyle(color:)。
    // TextStyle 不像 CupertinoListTile 的默认样式那样自动解算，暗色档会按亮档
    // 黑色绘制 —— 黑底黑字，名称不可见。直接解算即可（label 本身就是动态色）。
    final color = CupertinoColors.label.resolveFrom(context);
    final tile = CupertinoListTile(
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
      trailing: _trailing(
        context,
        ref: ref,
        folder: folder,
        smart: smart,
        count: count,
        countKey: countKey,
      ),
    );
    // #373：Apple 备忘录可 Control-click 文件夹 → 重新命名 / 删除。
    // 智能文件夹（所有备忘录/最近删除等）不提供这两项——它们是内置视图。
    if (folder == null || smart) {
      return tile;
    }
    return CupertinoContextMenu(
      key: ValueKey('note_folder_menu_${folder.id}'),
      actions: <Widget>[
        CupertinoContextMenuAction(
          key: ValueKey('note_folder_rename_${folder.id}'),
          onPressed: () {
            Navigator.of(context).pop();
            _renameFolder(context, ref, folder);
          },
          child: const Text('重新命名文件夹'),
        ),
        CupertinoContextMenuAction(
          key: ValueKey('note_folder_delete_${folder.id}'),
          isDestructiveAction: true,
          onPressed: () {
            Navigator.of(context).pop();
            _deleteFolder(context, ref, folder);
          },
          child: const Text('删除文件夹'),
        ),
      ],
      child: tile,
    );
  }

  /// 行尾：数量徽章 +（仅普通文件夹）「…」菜单。
  ///
  /// 两者必须并排进同一个 trailing：`CupertinoListTile` 只有一个 trailing 槽位，
  /// 之前被「…」占着，徽章就没有落点（#393）。
  Widget? _trailing(
    BuildContext context, {
    required WidgetRef ref,
    required NoteFolder? folder,
    required bool smart,
    required int? count,
    required String? countKey,
  }) {
    final children = <Widget>[
      if (count != null && countKey != null)
        _countBadge(context, countKey: countKey, count: count),
      if (folder != null && !smart)
        CupertinoButton(
          key: ValueKey('note_folder_more_${folder.id}'),
          padding: const EdgeInsets.all(6),
          minimumSize: Size.zero,
          onPressed: () => _showFolderActions(context, ref, folder),
          child: const Icon(
            CupertinoIcons.ellipsis,
            size: 16,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
    ];
    if (children.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  /// 数量徽章（#393）：Apple 在侧栏每行右端给出该容器的备忘录条数，0 也照样给
  /// （空文件夹不显示数字就分不清「空」和「没算」）。
  Widget _countBadge(
    BuildContext context, {
    required String countKey,
    required int count,
  }) {
    return Text(
      '$count',
      key: ValueKey(countKey),
      style: TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }

  /// 标签行（#393）：与文件夹行同款排布，但没有重命名/删除——标签本身还没有
  /// 独立的增删端口（矩阵 N13 的对等面是「按标签浏览」，管理标签另单）。
  Widget _tagTile(
    BuildContext context, {
    required Key key,
    required String name,
    required bool selected,
    required int count,
    required String countKey,
    required VoidCallback onTap,
  }) {
    final color = CupertinoColors.label.resolveFrom(context);
    final accent = selected
        ? CupertinoColors.systemBlue.resolveFrom(context)
        : color;
    return CupertinoListTile(
      key: key,
      padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
      leading: Icon(CupertinoIcons.tag, size: 20, color: accent),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: accent,
        ),
      ),
      onTap: onTap,
      trailing: _countBadge(context, countKey: countKey, count: count),
    );
  }

  /// 「…」按钮的动作表（#373）。
  ///
  /// Apple 用 Control-click 的上下文菜单承载这两个命令；本仓也做了
  /// `CupertinoContextMenu`，但上下文菜单在桌面端不易发现，且 widget 测试里
  /// 难以稳定驱动（decoy 动画 + 手势仲裁），所以额外给一个显式入口——
  /// 同一组命令、同一段实现。
  Future<void> _showFolderActions(
      BuildContext context, WidgetRef ref, NoteFolder folder) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(folder.name),
        actions: [
          CupertinoActionSheetAction(
            key: ValueKey('note_folder_action_rename_${folder.id}'),
            onPressed: () => Navigator.of(ctx).pop('rename'),
            child: const Text('重新命名文件夹'),
          ),
          CupertinoActionSheetAction(
            key: ValueKey('note_folder_action_delete_${folder.id}'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: const Text('删除文件夹'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    // 弹窗关闭后 context 可能已失效（异步间隙）：两个分支各自再判一次 mounted。
    if (action == 'rename' && context.mounted) {
      await _renameFolder(context, ref, folder);
    }
    if (action == 'delete' && context.mounted) {
      await _deleteFolder(context, ref, folder);
    }
  }

  /// 重新命名（#373）：复用「新建文件夹」的输入弹窗，带初始值。
  Future<void> _renameFolder(
      BuildContext context, WidgetRef ref, NoteFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    controller.selection =
        TextSelection(baseOffset: 0, extentOffset: folder.name.length);
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => LifeAlertDialog(
        title: const Text('重新命名文件夹'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            key: const ValueKey('note_rename_folder_name'),
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
            key: const ValueKey('note_rename_folder_ok'),
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('好'),
          ),
        ],
      ),
    );
    final title = (name ?? '').trim();
    if (title.isEmpty || title == folder.name) return;
    await ref.read(noteRepositoryProvider).upsertFolder(NoteFolder(
          id: folder.id,
          parentId: folder.parentId,
          name: title,
          smart: folder.smart,
          filterJson: folder.filterJson,
          sortOrder: folder.sortOrder,
        ));
  }

  /// 删除（#373）：Apple 语义——先把手里的笔记移入「最近删除」，再删文件夹。
  Future<void> _deleteFolder(
      BuildContext context, WidgetRef ref, NoteFolder folder) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => LifeAlertDialog(
        title: const Text('删除文件夹'),
        content: Text('「${folder.name}」及其中（含子文件夹）的备忘录将移到「最近删除」。'),
        actions: [
          LifeDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          LifeDialogAction(
            key: const ValueKey('note_delete_folder_ok'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(noteRepositoryProvider);

    // #379：必须**递归**。只处理直接子级会留下 parentId 指向已删行的孤儿文件夹——
    // 侧栏按 `parentId == null` 取根，它们从此看不见但数据还在库里；更糟的是
    // 子文件夹里的笔记既不在任何可见文件夹里、也不在「最近删除」里，等于静默丢失。
    final all = await repo.watchFolders().first;
    final subtree = <NoteFolder>[];
    final seen = <String>{};
    final queue = <NoteFolder>[folder];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!seen.add(current.id)) continue; // 防 parentId 成环时的死循环
      subtree.add(current);
      queue.addAll(all.where((f) => f.parentId == current.id));
    }

    // 先把整棵子树的笔记移入「最近删除」（可恢复），再删文件夹本身。
    for (final node in subtree) {
      final notes = await repo.watchNotes(folderId: node.id).first;
      for (final note in notes) {
        await repo.softDelete(note.id);
      }
    }
    // 自底向上删，避免中途出现「父已删、子还在」的瞬时孤儿。
    for (final node in subtree.reversed) {
      await repo.deleteFolder(node.id);
    }
    _selectFolder(ref, null);
  }

  static int _compareFolders(NoteFolder a, NoteFolder b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
  }
}
