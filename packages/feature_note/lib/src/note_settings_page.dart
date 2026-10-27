import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'providers.dart';

/// 记录设置（F-13）：默认文件夹与排序方式，本地偏好。
class NoteSettingsPage extends ConsumerWidget {
  const NoteSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(noteSettingsProvider);
    final folders =
        ref.watch(noteFoldersProvider).value ?? const <NoteFolder>[];
    return Scaffold(
      appBar: AppBar(title: const Text('记录设置')),
      body: ListView(
        children: [
          const ListTile(title: Text('默认文件夹')),
          ListTile(
            title: const Text('新备忘录保存到'),
            trailing: DropdownButton<String>(
              key: const ValueKey('note_default_folder'),
              value: settings.defaultFolderId ?? '',
              items: [
                const DropdownMenuItem(value: '', child: Text('当前文件夹')),
                for (final folder in folders)
                  if (!folder.smart)
                    DropdownMenuItem(
                      value: folder.id,
                      child: Text(folder.name),
                    ),
              ],
              onChanged: (value) => ref
                  .read(noteSettingsProvider.notifier)
                  .setDefaultFolder(
                      value == null || value.isEmpty ? null : value),
            ),
          ),
          const Divider(),
          const ListTile(title: Text('排序')),
          for (final option in const [
            (NoteSortMode.custom, '自定义（置顶优先）', 'note_sort_custom'),
            (NoteSortMode.title, '按标题', 'note_sort_title'),
            (NoteSortMode.updated, '按修改时间', 'note_sort_updated'),
          ])
            ListTile(
              key: ValueKey(option.$3),
              title: Text(option.$2),
              trailing: settings.sortMode == option.$1
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => ref
                  .read(noteSettingsProvider.notifier)
                  .setSortMode(option.$1),
            ),
        ],
      ),
    );
  }
}
