import 'package:app_ui/app_ui.dart';
import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:app_core/app_core.dart';

import 'note_editor_page.dart';
import 'note_search_highlight.dart';
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

  /// #687：宽屏列表栏宽于编辑栏（Apple 备忘录同向）。原先 4:5 列表偏窄。
  static const int listFlex = 5;
  static const int editorFlex = 4;

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
    // #658：相对日期以同一时刻为准，整屏文案不会各算各的。
    final now = ref.watch(noteClockProvider)();
    // 日期节头（#392 / #659）：设置里的「按日期分组备忘录」勾选是总闸，
    // Apple 在「按标题」档下自己也不摆节头，两条都得让位。节头文案自 #659 起
    // 改「今天 / 昨天 / 本周 / 更早」，不再按自然年。
    final groupByDate =
        settings.groupByDate && settings.sortMode != NoteSortMode.title;
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
                        flex: NoteScaffold.listFlex,
                        child: _NoteList(
                          showSearch: false,
                          gallery: gallery,
                          groupByDate: groupByDate,
                          query: query,
                          now: now,
                          emptyLabel: searching ? '无匹配结果' : '没有备忘录',
                          onSearch: (value) => ref
                              .read(noteSearchQueryProvider.notifier)
                              .setQuery(value),
                          notes: sortedNotes,
                          // #421：宽屏是**选中就地编辑**，不是推入页。
                          onTap: (note) {
                            ref
                                .read(selectedNoteIdProvider.notifier)
                                .select(note.id);
                          },
                          onPin: (note) => _togglePin(ref, note),
                          onDelete: (note) => ref
                              .read(noteRepositoryProvider)
                              .softDelete(note.id),
                        ),
                      ),
                      const _Separator(),
                      // 第三栏：内嵌编辑器（选中即编辑；未选给空态）。
                      Expanded(
                        flex: NoteScaffold.editorFlex,
                        child: _NoteEditorPane(notes: sortedNotes),
                      ),
                    ],
                  )
                : _NoteList(
                    gallery: gallery,
                    groupByDate: groupByDate,
                    query: query,
                    now: now,
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
    // #410：老数据迁移。`#395` 之前「锁定」只写 `locked: true`、正文仍是明文，
    // 于是升级后这些备忘录**永远解不开**（open() 对明文必然失败）。
    // 检测到这种行时改走「设置新口令并就地加密」，不要求旧口令（旧口令从未生效）。
    if (!NoteLockCodec.isSealed(note.bodyDelta)) {
      await _migrateLegacyLock(context, ref, note);
      return;
    }
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

  /// 旧「锁定」备忘录迁移（#410）：如实告知此前未加密，请用户设置新口令。
  ///
  /// 不静默加密：用户需要知道「这段内容在设置口令之前是可读的」，
  /// 否则会误以为一直受保护。
  Future<void> _migrateLegacyLock(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final passwordController = TextEditingController();
    final passphrase = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => LifeAlertDialog(
        title: const Text('为这条备忘录设置密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                '这条备忘录此前只有「锁定」标记，正文并未加密。'
                '设置密码后会立即加密保存。',
                key: ValueKey('note_lock_migration_notice'),
              ),
            ),
            CupertinoTextField(
              key: const ValueKey('note_lock_migration_password'),
              controller: passwordController,
              obscureText: true,
              placeholder: '输入密码',
            ),
          ],
        ),
        actions: [
          LifeDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          LifeDialogAction(
            key: const ValueKey('note_lock_migration_confirm'),
            isDefaultAction: true,
            onPressed: () {
              final value = passwordController.text.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('加密并锁定'),
          ),
        ],
      ),
    );
    if (passphrase == null || passphrase.isEmpty || !context.mounted) {
      return;
    }
    final repo = ref.read(noteRepositoryProvider);
    final sealed = NoteLockCodec.seal(note.bodyDelta, passphrase);
    await repo.upsertNote(Note(
      id: note.id,
      folderId: note.folderId,
      title: note.title,
      bodyDelta: sealed,
      bodyText: '', // 锁定内容不进搜索索引（与 #395 一致）
      pinned: note.pinned,
      locked: true,
      tagNames: note.tagNames,
      sortOrder: note.sortOrder,
      revision: note.revision + 1,
      clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!context.mounted) return;
    // 迁移完直接进编辑器（用户刚证明了自己能设这个口令）
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => NoteEditorPage(
          folderId: note.folderId,
          note: Note(
            id: note.id,
            folderId: note.folderId,
            title: note.title,
            bodyDelta: note.bodyDelta,
            pinned: note.pinned,
            locked: true,
            tagNames: note.tagNames,
            sortOrder: note.sortOrder,
            revision: note.revision + 1,
            clientUpdatedAt: note.clientUpdatedAt,
          ),
          unlockPassphrase: passphrase,
          unlockedInitial: true,
        ),
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
    required this.query,
    this.showSearch = true,
    required this.emptyLabel,
    required this.gallery,
    required this.groupByDate,
    required this.now,
  });

  final DateTime now;
  final List<Note> notes;
  final ValueChanged<Note> onTap;
  final ValueChanged<Note> onPin;
  final ValueChanged<Note> onDelete;
  final ValueChanged<String> onSearch;

  /// 搜索词（已 trim）：非空时列表标题与摘要里的命中词加底色（#660）。
  final String query;

  /// 窄屏为 true。宽屏搜索在侧栏（#689），列表不再重复一块。
  final bool showSearch;
  final String emptyLabel;
  final bool gallery;

  /// 按编辑日期分相对桶（#659，矩阵 N12/N25）。按标题排序时关掉——
  /// Apple 在同档下也不摆日期节头。
  final bool groupByDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showSearch)
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
                    NoteMatchText(
                      note.title,
                      query: query,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: NoteMatchText(
                        note.locked ? '已锁定' : note.bodyText,
                        query: query,
                        maxLines: 4,
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
    final rows = _groupedRows();
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];
        if (row is _NoteGroup) return _NoteGroupHeader(group: row);
        final note = row as Note;
        return _NoteRow(
          note: note,
          query: query,
          now: now,
          onTap: onTap,
          onPin: onPin,
          onDelete: onDelete,
        );
      },
    );
  }

  /// 列表行序（#659）：按「今天 / 昨天 / 本周 / 更早」四个相对桶分节，
  /// 桶内保持传入顺序（置顶优先等既有语义不丢）；无编辑时间的排在所有桶之后、
  /// 不摆节头。一条带日期的都没有时原样返回——golden 夹具即此形态，基线因此不变。
  List<Object> _groupedRows() {
    if (!groupByDate) return notes;
    final buckets = <_NoteGroup, List<Note>>{};
    final undated = <Note>[];
    for (final note in notes) {
      if (note.clientUpdatedAt <= 0) {
        undated.add(note);
        continue;
      }
      final edited = DateTime.fromMillisecondsSinceEpoch(note.clientUpdatedAt);
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfEdited = DateTime(edited.year, edited.month, edited.day);
      final days = startOfToday.difference(startOfEdited).inDays;
      // 未来编辑时间（days < 0）不单独造桶，与旧笔记一起归「更早」。
      final _NoteGroup group;
      if (days == 0) {
        group = _NoteGroup.today;
      } else if (days == 1) {
        group = _NoteGroup.yesterday;
      } else if (days >= 2 && days <= 6) {
        group = _NoteGroup.thisWeek;
      } else {
        group = _NoteGroup.earlier;
      }
      (buckets[group] ??= <Note>[]).add(note);
    }
    if (buckets.isEmpty) return notes;
    const order = <_NoteGroup>[
      _NoteGroup.today,
      _NoteGroup.yesterday,
      _NoteGroup.thisWeek,
      _NoteGroup.earlier,
    ];
    return <Object>[
      for (final group in order)
        if (buckets.containsKey(group)) ...[group, ...buckets[group]!],
      ...undated,
    ];
  }
}

/// 备忘录列表行：标题 + 编辑日期 + 摘要（#391，Apple 同结构）。
class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.query,
    required this.now,
    required this.onTap,
    required this.onPin,
    required this.onDelete,
  });

  final Note note;

  /// 搜索词（已 trim）：非空时标题与摘要里的命中词加底色（#660）。
  final String query;
  final DateTime now;
  final ValueChanged<Note> onTap;
  final ValueChanged<Note> onPin;
  final ValueChanged<Note> onDelete;

  @override
  Widget build(BuildContext context) {
    final date = _noteDateLabel(note, now: now);
    final tile = GestureDetector(
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
                    NoteMatchText(
                      note.title,
                      query: query,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (date != null)
                      Text(
                        date,
                        key: ValueKey('note_row_date_${note.id}'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    NoteMatchText(
                      note.locked ? '已锁定' : note.bodyText,
                      query: query,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              // #666：Apple 列表行会标出媒体类型。图片以 noteImage embed 存在
              // 正文 Delta 里；锁定笔记的正文是密文，不探测。
              if (!note.locked && note.bodyDelta.contains('"noteImage"'))
                Padding(
                  key: ValueKey('note_row_media_image_${note.id}'),
                  padding: const EdgeInsets.only(top: 2, right: 2),
                  child: const Icon(
                    CupertinoIcons.photo,
                    size: 18,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    // #688：行内不再放置顶/删除。右键菜单与左滑删除保留这两件事。
    return CupertinoMenuAnchor(
      menuChildren: [
        CupertinoMenuItem(
          key: ValueKey('note_pin_${note.id}'),
          onPressed: () => onPin(note),
          child: Text(note.pinned ? '取消置顶' : '置顶'),
        ),
        CupertinoMenuItem(
          key: ValueKey('note_delete_${note.id}'),
          isDestructiveAction: true,
          onPressed: () => onDelete(note),
          child: const Text('删除'),
        ),
      ],
      builder: (context, controller, child) => GestureDetector(
        onSecondaryTapUp: (details) =>
            controller.open(position: details.localPosition),
        child: Dismissible(
          key: ValueKey('note_dismiss_${note.id}'),
          direction: DismissDirection.endToStart,
          background: const ColoredBox(
            color: CupertinoColors.systemRed,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(CupertinoIcons.delete, color: CupertinoColors.white),
              ),
            ),
          ),
          onDismissed: (_) => onDelete(note),
          child: child!,
        ),
      ),
      child: tile,
    );
  }
}

/// 日期分组桶（#659）：Apple 按相对日期分节，不再按自然年。
enum _NoteGroup { today, yesterday, thisWeek, earlier }

const _groupLabels = <_NoteGroup, String>{
  _NoteGroup.today: '今天',
  _NoteGroup.yesterday: '昨天',
  _NoteGroup.thisWeek: '本周',
  _NoteGroup.earlier: '更早',
};

/// 相对日期分组的节头（#659）。key 沿用 `note_group_` 前缀，便于按桶定位。
class _NoteGroupHeader extends StatelessWidget {
  const _NoteGroupHeader({required this.group});

  final _NoteGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('note_group_${group.name}'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Text(
        _groupLabels[group]!,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: CupertinoColors.secondaryLabel,
        ),
      ),
    );
  }
}

const _weekdayLabels = <int, String>{
  1: '星期一',
  2: '星期二',
  3: '星期三',
  4: '星期四',
  5: '星期五',
  6: '星期六',
  7: '星期日',
};

/// 行内编辑日期（#658 / TC-NOTE-UI-117）：Apple 备忘录对近期笔记写相对日期
/// 「今天 / 昨天 / 星期X」，同年的较早笔记写「M月d日」，跨年写「yyyy年M月d日」。
/// now 由 noteClockProvider 注入，测试固定到某一刻以免文案随运行当天漂移。
/// `clientUpdatedAt <= 0` 是未落库/无编辑时间，返回 null 而不是显示 1970/1/1 假日期。
String? _noteDateLabel(Note note, {required DateTime now}) {
  if (note.clientUpdatedAt <= 0) return null;
  final edited = DateTime.fromMillisecondsSinceEpoch(note.clientUpdatedAt);
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfEdited = DateTime(edited.year, edited.month, edited.day);
  final days = startOfToday.difference(startOfEdited).inDays;
  if (days == 0) return '今天';
  if (days == 1) return '昨天';
  if (days >= 2 && days <= 6) return _weekdayLabels[edited.weekday]!;
  if (edited.year == now.year) return '${edited.month}月${edited.day}日';
  return '${edited.year}年${edited.month}月${edited.day}日';
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

/// 第三栏：内嵌编辑器（#421）。
///
/// 未选中时给空态，而不是「空白编辑器」——Apple 备忘录在没选中时也是空态，
/// 避免用户对着一个不知属于哪条记录的编辑器打字。
class _NoteEditorPane extends ConsumerWidget {
  const _NoteEditorPane({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedNoteIdProvider);
    if (selectedId == null) {
      return const Center(
        key: Key('note_editor_pane_empty'),
        child: Text(
          '选择一条备忘录，或点「快速记录」新建',
          style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
        ),
      );
    }
    final note = notes.where((n) => n.id == selectedId).firstOrNull;
    if (note == null) {
      // 选中项被删除/移出列表：回到空态，不要把上一条的内容留在栏里。
      return const Center(
        key: Key('note_editor_pane_missing'),
        child: Text(
          '这条备忘录已不在当前列表',
          style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
        ),
      );
    }
    // key 带 note.id：切换记录时重建编辑器，避免上一条的内容/光标残留。
    return NoteEditorPage(
      key: ValueKey('note_editor_pane_${note.id}'),
      note: note,
      folderId: note.folderId,
      embedded: true,
    );
  }
}
