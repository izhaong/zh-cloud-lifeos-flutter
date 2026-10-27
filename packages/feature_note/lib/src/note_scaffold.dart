import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'note_editor_page.dart';
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
    final notes = ref.watch(visibleNotesProvider).value ?? const <Note>[];
    final folders =
        ref.watch(noteFoldersProvider).value ?? const <NoteFolder>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        return Scaffold(
          appBar: AppBar(title: const Text('记录')),
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
                          notes: notes,
                          onTap: (note) =>
                              _openEditor(context, ref, note, folders),
                        ),
                      ),
                    ],
                  ),
                )
              : _NoteList(
                  notes: notes,
                  onTap: (note) => _openEditor(context, ref, note, folders),
                ),
        );
      },
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, Note? note,
      List<NoteFolder> folders) {
    final selectedId = ref.read(selectedNoteFolderIdProvider);
    final folderId = note?.folderId ??
        selectedId ??
        (folders.isEmpty ? null : folders.first.id);
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
  const _NoteList({required this.notes, required this.onTap});

  final List<Note> notes;
  final ValueChanged<Note> onTap;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const _EmptyHint();
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
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.note_outlined, size: 48),
          SizedBox(height: 8),
          Text('没有备忘录'),
        ],
      ),
    );
  }
}
