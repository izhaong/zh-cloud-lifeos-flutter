import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'note_editor_page.dart';
import 'note_recycle_page.dart';
import 'note_settings_page.dart';
import 'note_sidebar.dart';
import 'providers.dart';

/// 记录主脚手架（F-03 骨架 / F-04 侧栏；编辑器随 F-05）。
///
/// 宽屏左右分栏（侧栏 + 列表）；窄屏侧栏收进 Drawer。
/// 不出现 iCloud/Siri 等生态文案（契约 §9）。
class NoteScaffold extends ConsumerWidget {
  const NoteScaffold({super.key});

  static const double wideBreakpoint = 600;
  static const double sidebarWidth = 220;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            (a, b) => b.clientUpdatedAt.compareTo(a.clientUpdatedAt));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        return Scaffold(
          appBar: AppBar(
            title: const Text('记录'),
            actions: [
              IconButton(
                key: const ValueKey('note_settings'),
                tooltip: '记录设置',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NoteSettingsPage(),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('note_quick_capture'),
                tooltip: '快速记录',
                icon: const Icon(Icons.bolt_outlined),
                onPressed: () => _quickCapture(context, ref, folders),
              ),
              IconButton(
                key: const ValueKey('note_view_toggle'),
                tooltip: gallery ? '列表视图' : '画廊视图',
                icon: Icon(gallery ? Icons.view_list : Icons.grid_view),
                onPressed: () =>
                    ref.read(noteGalleryModeProvider.notifier).toggle(),
              ),
              IconButton(
                key: const ValueKey('note_recycle'),
                tooltip: '最近删除',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NoteRecyclePage(),
                  ),
                ),
              ),
            ],
          ),
          drawer: wide ? null : const Drawer(child: SafeArea(child: NoteSidebar())),
          floatingActionButton: FloatingActionButton(
            key: const ValueKey('note_new'),
            tooltip: '新建备忘录',
            onPressed: () => _openEditor(context, ref, null, folders),
            child: const Icon(Icons.add),
          ),
          body: wide
              ? SafeArea(
                  child: Row(
                    children: [
                      const SizedBox(
                        width: sidebarWidth,
                        child: NoteSidebar(),
                      ),
                      const VerticalDivider(width: 1),
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
                          onDelete: (note) =>
                              ref.read(noteRepositoryProvider).softDelete(note.id),
                        ),
                      ),
                    ],
                  ),
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
        );
      },
    );
  }

  Future<void> _quickCapture(
      BuildContext context, WidgetRef ref, List<NoteFolder> folders) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先新建一个文件夹')),
      );
      return;
    }
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('快速记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('note_quick_title'),
              controller: titleController,
              decoration: const InputDecoration(hintText: '标题'),
            ),
            TextField(
              key: const ValueKey('note_quick_body'),
              controller: bodyController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: '正文'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('note_quick_save'),
            onPressed: () async {
              final title = titleController.text.trim();
              final body = bodyController.text;
              await ref.read(noteRepositoryProvider).upsertNote(Note(
                    id: 'note-${DateTime.now().millisecondsSinceEpoch}',
                    folderId: target!.id,
                    title: title.isEmpty ? '快速记录' : title,
                    bodyDelta: jsonEncode({
                      'ops': [
                        {'insert': '$body\n'},
                      ],
                    }),
                    clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
                  ));
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
      BuildContext context, WidgetRef ref, Note note) async {
    final passwordController = TextEditingController();
    final unlocked = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('解锁备忘录'),
        content: TextField(
          key: const ValueKey('note_unlock_password'),
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: '输入密码'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('note_unlock_confirm'),
            onPressed: () => Navigator.of(dialogContext)
                .pop(passwordController.text.trim().isNotEmpty),
            child: const Text('解锁'),
          ),
        ],
      ),
    );
    if (unlocked != true || !context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorPage(
          note: note,
          folderId: note.folderId,
          unlockedInitial: true,
        ),
      ),
    );
  }

  void _togglePin(WidgetRef ref, Note note) {
    ref.read(noteRepositoryProvider).upsertNote(Note(
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
        ));
  }

  void _openEditor(BuildContext context, WidgetRef ref, Note? note,
      List<NoteFolder> folders) {
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
    final folderId = note?.folderId ??
        defaultFolderId ??
        (selected != null && !selected.smart ? selected.id : firstReal?.id);
    if (folderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先新建一个文件夹')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorPage(note: note, folderId: folderId),
      ),
    );
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
          child: TextField(
            key: const ValueKey('note_search_field'),
            onChanged: onSearch,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search),
              hintText: '搜索',
              border: OutlineInputBorder(),
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
          return Card(
            child: InkWell(
              onTap: () => onTap(note),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        note.locked ? '已锁定' : note.bodyText,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
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
        return ListTile(
          onTap: () => onTap(note),
          title: Text(
            note.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: note.locked
              ? const Text('已锁定', maxLines: 1)
              : Text(
                  note.bodyText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: ValueKey('note_pin_${note.id}'),
                tooltip: note.pinned ? '取消置顶' : '置顶',
                icon: Icon(
                  note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                onPressed: () => onPin(note),
              ),
              IconButton(
                key: ValueKey('note_delete_${note.id}'),
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(note),
              ),
            ],
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
          const Icon(Icons.note_outlined, size: 48),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}
