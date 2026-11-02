import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// #533：分区的**生产入口**。
///
/// 此前只有渲染没有入口：kernel 的 `upsertSection` / `reorderSection` /
/// `deleteSection` 在产品代码里零调用，列表「更多」菜单里是一条置灰的
/// 「按分区整理（规划）」占位。本文件把占位换成真入口。

/// 新建分区（Apple：工具栏「＋」/ 文件 > 新建分区）。
Future<void> showNewSectionDialog(
  BuildContext context, {
  required ReminderList list,
  required ReminderRepository repository,
}) {
  final controller = TextEditingController();
  return showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => LifeAlertDialog(
      title: const Text('新建分区'),
      content: CupertinoTextField(
        key: const ValueKey('new_section_name'),
        controller: controller,
        autofocus: true,
        placeholder: '分区名称',
      ),
      actions: [
        LifeDialogAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        LifeDialogAction(
          key: const ValueKey('new_section_submit'),
          isDefaultAction: true,
          onPressed: () async {
            final title = controller.text.trim();
            if (title.isEmpty) return;
            final navigator = Navigator.of(ctx);
            final last = list.sections.isEmpty
                ? null
                : list.sections.reduce(
                    (a, b) => a.sortOrder >= b.sortOrder ? a : b,
                  );
            await repository.upsertSection(
              listId: list.id,
              section: ReminderSection(
                id: newSectionId(),
                title: title,
                sortOrder: (last?.sortOrder ?? 0) + 1,
              ),
            );
            navigator.pop();
          },
          child: const Text('添加'),
        ),
      ],
    ),
  );
}

/// 分区编辑面板：重命名 / 上下移 / 删除。
Future<void> showSectionEditorSheet(
  BuildContext context, {
  required ReminderList list,
  required ReminderRepository repository,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => SectionEditorSheet(list: list, repository: repository),
  );
}

class SectionEditorSheet extends StatefulWidget {
  const SectionEditorSheet({
    super.key,
    required this.list,
    required this.repository,
  });

  final ReminderList list;
  final ReminderRepository repository;

  @override
  State<SectionEditorSheet> createState() => _SectionEditorSheetState();
}

class _SectionEditorSheetState extends State<SectionEditorSheet> {
  late final List<ReminderSection> _sections = List.of(widget.list.sections);
  late final Map<String, TextEditingController> _editors = {
    for (final s in _sections) s.id: TextEditingController(text: s.title),
  };

  @override
  void dispose() {
    for (final c in _editors.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _rename(ReminderSection section) async {
    final title = _editors[section.id]?.text.trim() ?? '';
    if (title.isEmpty || title == section.title) return;
    await widget.repository.upsertSection(
      listId: widget.list.id,
      section: section.copyWith(title: title),
    );
  }

  Future<void> _move(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _sections.length) return;
    setState(() {
      final moved = _sections.removeAt(index);
      _sections.insert(target, moved);
    });
    await widget.repository.reorderSection(
      listId: widget.list.id,
      sectionIds: [for (final s in _sections) s.id],
    );
  }

  Future<void> _delete(ReminderSection section) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => LifeAlertDialog(
        title: Text('删除分区「${section.title}」？'),
        content: const Text('分区内的提醒事项会回到「未分区」。'),
        actions: [
          LifeDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          LifeDialogAction(
            key: const ValueKey('section_delete_confirm'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.repository.deleteSection(
      listId: widget.list.id,
      sectionId: section.id,
    );
    if (!mounted) return;
    setState(() => _sections.removeWhere((e) => e.id == section.id));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(
        CupertinoColors.systemGroupedBackground,
        context,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Expanded(child: Text('编辑分区')),
                  CupertinoButton(
                    key: const ValueKey('section_editor_done'),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            if (_sections.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('还没有分区'))
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var i = 0; i < _sections.length; i++)
                      CupertinoListTile(
                        key: ValueKey('section_row_${_sections[i].id}'),
                        title: CupertinoTextField(
                          key: ValueKey('section_rename_${_sections[i].id}'),
                          controller: _editors[_sections[i].id],
                          onSubmitted: (_) => _rename(_sections[i]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoButton(
                              key: ValueKey('section_up_${_sections[i].id}'),
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.all(6),
                              onPressed: i == 0 ? null : () => _move(i, -1),
                              child: const Icon(CupertinoIcons.chevron_up),
                            ),
                            CupertinoButton(
                              key: ValueKey('section_down_${_sections[i].id}'),
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.all(6),
                              onPressed: i == _sections.length - 1
                                  ? null
                                  : () => _move(i, 1),
                              child: const Icon(CupertinoIcons.chevron_down),
                            ),
                            CupertinoButton(
                              key: ValueKey(
                                'section_delete_${_sections[i].id}',
                              ),
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.all(6),
                              onPressed: () => _delete(_sections[i]),
                              child: const Icon(CupertinoIcons.trash),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
