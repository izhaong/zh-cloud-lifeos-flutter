import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'providers.dart';
import 'package:app_core/app_core.dart';

/// 记录设置（F-13）：默认文件夹与排序方式，本地偏好。
class NoteSettingsPage extends ConsumerWidget {
  const NoteSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(noteSettingsProvider);
    final folders =
        ref.watch(noteFoldersProvider).value ?? const <NoteFolder>[];
    NoteFolder? defaultFolder;
    for (final folder in folders) {
      if (folder.id == settings.defaultFolderId) {
        defaultFolder = folder;
        break;
      }
    }

    Future<void> pickDefaultFolder() async {
      final selected = await showCupertinoModalPopup<String>(
        context: context,
        builder: (sheetContext) => LifeActionSheet(
          key: const Key('note_default_folder_sheet'),
          actions: [
            LifeActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop(''),
              child: const Text('当前文件夹'),
            ),
            for (final folder in folders)
              if (!folder.smart)
                LifeActionSheetAction(
                  key: ValueKey('note_default_folder_${folder.id}'),
                  onPressed: () => Navigator.of(sheetContext).pop(folder.id),
                  child: Text(folder.name),
                ),
          ],
          cancelButton: LifeActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('取消'),
          ),
        ),
      );
      if (selected == null) {
        return;
      }
      ref
          .read(noteSettingsProvider.notifier)
          .setDefaultFolder(selected.isEmpty ? null : selected);
    }

    Future<void> pickBeginWith() async {
      final selected = await showCupertinoModalPopup<String>(
        context: context,
        builder: (sheetContext) => LifeActionSheet(
          key: const Key('note_begin_with_sheet'),
          title: const Text('新备忘录开头格式'),
          actions: [
            for (final option in const [
              (NoteBeginWithMode.nothing, '无', 'note_begin_with_nothing'),
              (NoteBeginWithMode.title, '标题', 'note_begin_with_title'),
              (NoteBeginWithMode.body, '正文', 'note_begin_with_body'),
              (NoteBeginWithMode.checklist, '待办', 'note_begin_with_checklist'),
            ])
              LifeActionSheetAction(
                key: ValueKey(option.$3),
                onPressed: () => Navigator.of(sheetContext).pop(option.$1.name),
                child: Text(option.$2),
              ),
          ],
          cancelButton: LifeActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('取消'),
          ),
        ),
      );
      if (selected == null) {
        return;
      }
      ref
          .read(noteSettingsProvider.notifier)
          .setBeginWith(noteBeginWithModeFromId(selected));
    }

    return CupertinoPageScaffold(
      key: const Key('note_settings_page'),
      navigationBar: const CupertinoNavigationBar(middle: Text('记录设置')),
      child: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                '默认文件夹',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            CupertinoListTile(
              title: const Text('新备忘录保存到'),
              trailing: CupertinoButton(
                key: const ValueKey('note_default_folder'),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                onPressed: pickDefaultFolder,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      defaultFolder?.name ?? '当前文件夹',
                      style: const TextStyle(color: CupertinoColors.systemBlue),
                    ),
                    const Icon(
                      CupertinoIcons.chevron_up_chevron_down,
                      size: 14,
                      color: CupertinoColors.systemBlue,
                    ),
                  ],
                ),
              ),
            ),
            const _SectionSeparator(),
            CupertinoListTile(
              title: const Text('新备忘录开头格式'),
              trailing: CupertinoButton(
                key: const ValueKey('note_begin_with'),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                onPressed: pickBeginWith,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _beginWithLabels[settings.beginWith]!,
                      style: const TextStyle(color: CupertinoColors.systemBlue),
                    ),
                    const Icon(
                      CupertinoIcons.chevron_up_chevron_down,
                      size: 14,
                      color: CupertinoColors.systemBlue,
                    ),
                  ],
                ),
              ),
            ),
            const _SectionSeparator(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                '排序',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            for (final option in const [
              (NoteSortMode.custom, '自定义（置顶优先）', 'note_sort_custom'),
              (NoteSortMode.title, '按标题', 'note_sort_title'),
              (NoteSortMode.updated, '按修改时间', 'note_sort_updated'),
            ])
              CupertinoListTile(
                key: ValueKey(option.$3),
                title: Text(option.$2),
                trailing: settings.sortMode == option.$1
                    ? const Icon(
                        CupertinoIcons.check_mark,
                        color: CupertinoColors.systemBlue,
                      )
                    : null,
                onTap: () => ref
                    .read(noteSettingsProvider.notifier)
                    .setSortMode(option.$1),
              ),
            // Apple 用勾选框而不是开关控件表达这条，形态照搬（#392）。
            CupertinoListTile(
              key: const ValueKey('note_group_by_date'),
              title: const Text('按日期分组备忘录'),
              trailing: CupertinoCheckbox(
                value: settings.groupByDate,
                onChanged: (value) => ref
                    .read(noteSettingsProvider.notifier)
                    .setGroupByDate(value ?? true),
              ),
              onTap: () => ref
                  .read(noteSettingsProvider.notifier)
                  .setGroupByDate(!settings.groupByDate),
            ),
          ],
        ),
      ),
    );
  }
}

const _beginWithLabels = <NoteBeginWithMode, String>{
  NoteBeginWithMode.nothing: '无',
  NoteBeginWithMode.title: '标题',
  NoteBeginWithMode.body: '正文',
  NoteBeginWithMode.checklist: '待办',
};

class _SectionSeparator extends StatelessWidget {
  const _SectionSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(height: 0.5, color: CupertinoColors.separator);
  }
}
