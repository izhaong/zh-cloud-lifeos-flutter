import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'providers.dart';

/// 记录主脚手架（F-03 骨架；文件夹侧栏/编辑器随 F-04/F-05）。
///
/// 本卡只保证壳内入口可用：标题 + 空态；数据走 [noteRepositoryProvider]
/// 注入的实现。不出现 iCloud/Siri 等生态文案（契约 §9）。
class NoteScaffold extends ConsumerWidget {
  const NoteScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(visibleNotesProvider).value ?? const <Note>[];
    return Scaffold(
      appBar: AppBar(title: const Text('记录')),
      body: notes.isEmpty
          ? const _EmptyHint()
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
                  subtitle: note.locked
                      ? const Text('已锁定', maxLines: 1)
                      : Text(
                          note.bodyText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                );
              },
            ),
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
