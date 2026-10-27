import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'providers.dart';

/// 「最近删除」列表（F-06；契约 §1 30 天回收窗）。
class NoteRecyclePage extends ConsumerWidget {
  const NoteRecyclePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(deletedNotesProvider).value ?? const <Note>[];
    return Scaffold(
      appBar: AppBar(title: const Text('最近删除')),
      body: notes.isEmpty
          ? const Center(child: Text('没有最近删除的备忘录'))
          : ListView.builder(
              itemCount: notes.length,
              itemBuilder: (_, i) {
                final note = notes[i];
                return ListTile(
                  title: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    note.locked ? '已锁定' : note.bodyText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: TextButton(
                    key: ValueKey('note_restore_${note.id}'),
                    onPressed: () =>
                        ref.read(noteRepositoryProvider).restore(note.id),
                    child: const Text('恢复'),
                  ),
                );
              },
            ),
    );
  }
}
