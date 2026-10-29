import 'package:app_ui/app_ui.dart';
import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:app_core/app_core.dart';

import 'note_editor_page.dart';
import 'note_recycle_page.dart';
import 'note_settings_page.dart';
import 'note_sidebar.dart';
import 'providers.dart';

/// 记录主脚手架（F-03 骨架 / F-04 侧栏）。
///
/// 宽屏左右分栏（侧栏 + 列表）；窄屏侧栏收进底部弹层。
/// 不出现生态绑定文案（契约 §9）。
class NoteScaffold extends ConsumerStatefulWidget {
  const NoteScaffold({super.key});

  static const double wideBreakpoint = 600;
  static const double sidebarWidth = 220;

  @override
  ConsumerState<NoteScaffold> createState() => _NoteScaffoldState();
}

class _NoteScaffoldState extends ConsumerState<NoteScaffold> {
  /// 菜单命令（#375）：菜单栏拿不到页面 context，靠 app_core 的命令总线通知。
  ValueNotifier<LifeMenuAction?>? _menuCommands;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _menuCommands = ref.read(lifeMenuCommandsProvider);
      _menuCommands?.addListener(_onMenuCommand);
      _onMenuCommand(); // 命令先到、页面后挂载时补消费
    });
  }

  /// 文件 → 新建备忘录：与导航栏「＋」同一条路径（新建空备忘录并进编辑）。
  void _onMenuCommand() {
    final notifier = _menuCommands;
    if (notifier == null || notifier.value != LifeMenuAction.newNote) return;
    if (!mounted) return;
    notifier.value = null; // 消费即清，避免重建重复触发
    final folders = ref.read(noteFoldersProvider).value ?? const <NoteFolder>[];
    _openEditor(context, ref, null, folders);
  }

  @override
  void dispose() {
    _menuCommands?.removeListener(_onMenuCommand);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(noteSearchQueryProvider).trim();
    final searching = query.isNotEmpty;
    final notes = searching
        ? (ref.watch(noteSearchResultsProvider).value ?? const <Note>[])
        : (ref.watch(visibleNotesProvider).value ?? const <Note>[]);
    final folders =
        ref.watch(noteFoldersProvider).value ?? const <NoteFolder>[];
    final gallery = ref.watch(noteGalleryModeProvider);
    final settings = ref.watch(noteSettingsProvider);
    // 排序（F-13）：custom 保持仓库序（置顶优先），title/updated 为本地偏好
    final sortedNotes = List<Note>.of(notes);
    switch (settings.sortMode) {
      case NoteSortMode.custom:
        break;
      case NoteSortMode.title:
        sortedNotes.sort((a, b) => a.title.compareTo(b.title));
      case NoteSortMode.updated:
        sortedNotes.sort(
          (a, b) => b.clientUpdatedAt.compareTo(a.clientUpdatedAt),
        );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= NoteScaffold.wideBreakpoint;
        return CupertinoPageScaffold(
          key: const Key('note_scaffold'),
          navigationBar: CupertinoNavigationBar(
            middle: const Text('记录'),
            leading: wide
                ? null
                : CupertinoButton(
                    key: const ValueKey('note_sidebar_open'),
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    onPressed: () => _showSidebarSheet(context),
                    child: const Icon(CupertinoIcons.sidebar_left),
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavBarIcon(
                  key: const ValueKey('note_settings'),
                  semanticLabel: '记录设置',
                  icon: CupertinoIcons.gear,
                  onPressed: () => _push(context, const NoteSettingsPage()),
                ),
                _NavBarIcon(
                  key: const ValueKey('note_quick_capture'),
                  semanticLabel: '快速记录',
                  icon: CupertinoIcons.bolt,
                  onPressed: () => _quickCapture(context, ref, folders),
                ),
                _NavBarIcon(
                  key: const ValueKey('note_view_toggle'),
                  semanticLabel: gallery ? '列表视图' : '画廊视图',
                  icon: gallery
                      ? CupertinoIcons.list_bullet
                      : CupertinoIcons.square_grid_2x2,
                  onPressed: () =>
                      ref.read(noteGalleryModeProvider.notifier).toggle(),
                ),
                _NavBarIcon(
                  key: const ValueKey('note_recycle'),
                  semanticLabel: '最近删除',
                  icon: CupertinoIcons.delete,
                  onPressed: () => _push(context, const NoteRecyclePage()),
                ),
                _NavBarIcon(
                  key: const ValueKey('note_new'),
                  semanticLabel: '新建备忘录',
                  icon: CupertinoIcons.add_circled,
                  onPressed: () => _openEditor(context, ref, null, folders),
                ),
              ],
            ),
          ),
          child: SafeArea(
            child: wide
                ? Row(
                    children: [
                      const SizedBox(width: NoteScaffold.sidebarWidth, child: NoteSidebar()),
                      const _Separator(),
                      Expanded(
                        child: _NoteList(
                          gallery: gallery,
                          emptyLabel: searching ? '无匹配结果' : '没有备忘录',
                          onSearch: (value) => ref
                              .read(noteSearchQueryProvider.notifier)
                              .setQuery(value),
                          notes: sortedNotes,
                          onTap: (note) =>
                              _openEditor(context, ref, note, folders),
                          onPin: (note) => _togglePin(ref, note),
                          onDelete: (note) => ref
                              .read(noteRepositoryProvider)
                              .softDelete(note.id),
                        ),
                      ),
                    ],
                  )
                : _NoteList(
                    gallery: gallery,
                    emptyLabel: searching ? '无匹配结果' : '没有备忘录',
                    onSearch: (value) => ref
                        .read(noteSearchQueryProvider.notifier)
                        .setQuery(value),
                    notes: sortedNotes,
                    onTap: (note) => _openEditor(context, ref, note, folders),
                    onPin: (note) => _togglePin(ref, note),
                    onDelete: (note) =>
                        ref.read(noteRepositoryProvider).softDelete(note.id),
                  ),
          ),
        );
      },
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
  }

  void _showSidebarSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: ColoredBox(
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.systemBackground,
            context,
          ),
          child: const SizedBox(
            height: 420,
            child: SafeArea(top: false, child: NoteSidebar()),
          ),
        ),
      ),
    );
  }

  Future<void> _quickCapture(
    BuildContext context,
    WidgetRef ref,
    List<NoteFolder> folders,
  ) async {
    NoteFolder? target;
    final settings = ref.read(noteSettingsProvider);
    final selectedId = ref.read(selectedNoteFolderIdProvider);
    for (final folder in folders) {
      if (!folder.smart && folder.id == settings.defaultFolderId) {
        target = folder;
        break;
      }
    }
    for (final folder in folders) {
      if (target == null && !folder.smart && folder.id == selectedId) {
        target = folder;
        break;
      }
    }
    for (final folder in folders) {
      if (target == null && !folder.smart) {
        target = folder;
      }
    }
    if (target == null) {
      await _infoDialog(context, '先新建一个文件夹');
      return;
    }
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => LifeAlertDialog(
        title: const Text('快速记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              key: const ValueKey('note_quick_title'),
              controller: titleController,
              placeholder: '标题',
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              key: const ValueKey('note_quick_body'),
              controller: bodyController,
              maxLines: 4,
              placeholder: '正文',
            ),
          ],
        ),
        actions: [
          LifeDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          LifeDialogAction(
            key: const ValueKey('note_quick_save'),
            onPressed: () async {
              final title = titleController.text.trim();
              final body = bodyController.text;
              await ref
                  .read(noteRepositoryProvider)
                  .upsertNote(
                    Note(
                      id: 'note-${DateTime.now().millisecondsSinceEpoch}',
                      folderId: target!.id,
                      title: title.isEmpty ? '快速记录' : title,
                      bodyDelta: jsonEncode({
                        'ops': [
                          {'insert': '$body\n'},
                        ],
                      }),
                      clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
                    ),
                  );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _promptUnlock(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final passwordController = TextEditingController();
    String? plainDelta;
    String? passphraseUsed;
    final unlocked = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => LifeAlertDialog(
        title: const Text('解锁备忘录'),
        content: CupertinoTextField(
          key: const ValueKey('note_unlock_password'),
          controller: passwordController,
          obscureText: true,
          placeholder: '输入密码',
        ),
        actions: [
          LifeDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          LifeDialogAction(
            key: const ValueKey('note_unlock_confirm'),
            onPressed: () {
              // #395：口令必须**真的校验**——此前只要非空就算解锁。
              final passphrase = passwordController.text.trim();
              if (passphrase.isEmpty) return;
              try {
                final plain = NoteLockCodec.open(note.bodyDelta, passphrase);
                plainDelta = plain;
                passphraseUsed = passphrase;
                Navigator.of(dialogContext).pop(true);
              } on NoteLockException {
                Navigator.of(dialogContext).pop(false);
              }
            },
            child: const Text('解锁'),
          ),
        ],
      ),
    );
    if (unlocked != true || !context.mounted || plainDelta == null) {
      return;
    }
    // 解密后的正文只在内存里交给编辑器；库里仍是密文。
    // 口令一并传入——编辑器保存时要重新加密，否则一保存就退回明文。
    final unlockedNote = Note(
      id: note.id,
      folderId: note.folderId,
      title: note.title,
      bodyDelta: plainDelta!,
      bodyText: note.bodyText,
      pinned: note.pinned,
      locked: note.locked,
      tagNames: note.tagNames,
      sortOrder: note.sortOrder,
      revision: note.revision,
      clientUpdatedAt: note.clientUpdatedAt,
    );
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => NoteEditorPage(
          note: unlockedNote,
          unlockPassphrase: passphraseUsed,
          folderId: note.folderId,
          unlockedInitial: true,
        ),
      ),
    );
  }

  void _togglePin(WidgetRef ref, Note note) {
    ref
        .read(noteRepositoryProvider)
        .upsertNote(
          Note(
            id: note.id,
            folderId: note.folderId,
            title: note.title,
            bodyDelta: note.bodyDelta,
            bodyText: note.bodyText,
            pinned: !note.pinned,
            locked: note.locked,
            checklistTotal: note.checklistTotal,
            checklistDone: note.checklistDone,
            tagNames: note.tagNames,
            sortOrder: note.sortOrder,
            deletedAt: note.deletedAt,
            revision: note.revision + 1,
            clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  void _openEditor(
    BuildContext context,
    WidgetRef ref,
    Note? note,
    List<NoteFolder> folders,
  ) {
    if (note != null && note.locked) {
      _promptUnlock(context, ref, note);
      return;
    }
    final selectedId = ref.read(selectedNoteFolderIdProvider);
    NoteFolder? selected;
    for (final folder in folders) {
      if (folder.id == selectedId) {
        selected = folder;
        break;
      }
    }
    NoteFolder? firstReal;
    for (final folder in folders) {
      if (!folder.smart) {
        firstReal = folder;
        break;
      }
    }
    // 智能文件夹不是容器：新建笔记必须落在真实文件夹
    final settings = ref.read(noteSettingsProvider);
    String? defaultFolderId;
    for (final folder in folders) {
      if (!folder.smart && folder.id == settings.defaultFolderId) {
        defaultFolderId = folder.id;
        break;
      }
    }
    final folderId =
        note?.folderId ??
        defaultFolderId ??
        (selected != null && !selected.smart ? selected.id : firstReal?.id);
    if (folderId == null) {
      _infoDialog(context, '先新建一个文件夹');
      return;
    }
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => NoteEditorPage(note: note, folderId: folderId),
      ),
    );
  }

  Future<void> _infoDialog(BuildContext context, String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => LifeAlertDialog(
        content: Text(message),
        actions: [
          LifeDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }
}

class _NavBarIcon extends StatelessWidget {
  const _NavBarIcon({
    required Key key,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
  }) : super(key: key);

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        onPressed: onPressed,
        child: Icon(icon, size: 22),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(width: 0.5, color: CupertinoColors.separator);
  }
}

class _NoteList extends StatelessWidget {
  const _NoteList({
    required this.notes,
    required this.onTap,
    required this.onPin,
    required this.onDelete,
    required this.onSearch,
    required this.emptyLabel,
    required this.gallery,
  });

  final List<Note> notes;
  final ValueChanged<Note> onTap;
  final ValueChanged<Note> onPin;
  final ValueChanged<Note> onDelete;
  final ValueChanged<String> onSearch;
  final String emptyLabel;
  final bool gallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: CupertinoTextField(
            key: const ValueKey('note_search_field'),
            onChanged: onSearch,
            prefix: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(
                CupertinoIcons.search,
                size: 18,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            placeholder: '搜索',
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(LifeRadius.md),
            ),
          ),
        ),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (notes.isEmpty) {
      return _EmptyHint(label: emptyLabel);
    }
    if (gallery) {
      return GridView.builder(
        key: const ValueKey('note_gallery_grid'),
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.1,
        ),
        itemCount: notes.length,
        itemBuilder: (_, i) {
          final note = notes[i];
          return GestureDetector(
            onTap: () => onTap(note),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(LifeRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        note.locked ? '已锁定' : note.bodyText,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    return ListView.builder(
      itemCount: notes.length,
      itemBuilder: (_, i) {
        final note = notes[i];
        return GestureDetector(
          onTap: () => onTap(note),
          child: ColoredBox(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.systemBackground,
              context,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          note.locked ? '已锁定' : note.bodyText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    key: ValueKey('note_pin_${note.id}'),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    onPressed: () => onPin(note),
                    child: Icon(
                      note.pinned
                          ? CupertinoIcons.pin_fill
                          : CupertinoIcons.pin,
                      size: 20,
                      color: note.pinned
                          ? CupertinoColors.systemBlue
                          : CupertinoColors.secondaryLabel,
                    ),
                  ),
                  CupertinoButton(
                    key: ValueKey('note_delete_${note.id}'),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    onPressed: () => onDelete(note),
                    child: const Icon(
                      CupertinoIcons.delete,
                      size: 20,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.doc_text,
            size: 48,
            color: CupertinoColors.tertiaryLabel,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: CupertinoColors.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
