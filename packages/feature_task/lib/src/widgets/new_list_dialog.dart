import 'package:app_ui/app_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:app_core/app_core.dart';

/// 新建列表弹窗（名称 + 颜色 + 图标 + 类型；图4 全字段，TC-UI-115/316）。
///
/// - 类型：标准 / 日常采购（grocery 预置 8 分区模板，不做商品识别——HT105086 降级）
/// - 图标：8 个 Cupertino 预设（列表头展示用）
/// - 提交 = [onCreate]（由上层调 upsertList；id 走 [newListId] 工厂）
Future<void> showNewListDialog(
  BuildContext context, {
  required ValueChanged<ReminderList> onCreate,
}) {
  final titleController = TextEditingController();
  var colorArgb = 0xFF34C759;
  var listType = ReminderListType.standard;
  var iconId = 'list';

  const palette = <int>[
    0xFF34C759, // 绿
    0xFF007AFF, // 蓝
    0xFFFF9500, // 橙
    0xFFFF3B30, // 红
    0xFFAF52DE, // 紫
    0xFFFFCC00, // 黄
    0xFF5856D6, // 靛
    0xFF30B0C7, // 青
  ];

  return showCupertinoDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => LifeAlertDialog(
        title: const Text('新列表'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CupertinoTextField(
                key: const ValueKey('new_list_name'),
                controller: titleController,
                autofocus: true,
                placeholder: '列表名称',
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      CupertinoColors.tertiarySystemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(LifeRadius.md),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final c in palette)
                    GestureDetector(
                      key: ValueKey('color_$c'),
                      onTap: () => setState(() => colorArgb = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(c),
                        ),
                        child: colorArgb == c
                            ? const Icon(
                                CupertinoIcons.checkmark,
                                size: 16,
                                color: CupertinoColors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in presetListIcons.entries)
                    GestureDetector(
                      key: ValueKey('icon_${entry.key}'),
                      onTap: () => setState(() => iconId = entry.key),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconId == entry.key
                              ? Color(colorArgb)
                              : CupertinoColors.tertiarySystemFill
                                  .resolveFrom(context),
                        ),
                        child: Icon(
                          entry.value,
                          size: 18,
                          color: iconId == entry.key
                              ? CupertinoColors.white
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              CupertinoSlidingSegmentedControl<ReminderListType>(
                key: const ValueKey('list_type'),
                groupValue: listType,
                children: const {
                  ReminderListType.standard: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('标准', style: TextStyle(fontSize: 13)),
                  ),
                  ReminderListType.grocery: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('日常采购', style: TextStyle(fontSize: 13)),
                  ),
                },
                onValueChanged: (v) => setState(
                  () => listType = v ?? ReminderListType.standard,
                ),
              ),
            ],
          ),
        ),
        actions: [
          LifeDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          LifeDialogAction(
            key: const ValueKey('new_list_submit'),
            isDefaultAction: true,
            onPressed: () {
              final name = titleController.text.trim();
              if (name.isEmpty) return;
              final list = listType == ReminderListType.grocery
                  ? ReminderList.createGroceryList(
                      id: newListId(),
                      title: name,
                      colorArgb: colorArgb,
                    )
                  : ReminderList(
                      id: newListId(),
                      title: name,
                      colorArgb: colorArgb,
                    );
              onCreate(list);
              Navigator.of(context).pop();
            },
            child: const Text('完成'),
          ),
        ],
      ),
    ),
  );
}

/// 预设列表图标（图4；M4 同步后 listIcon 字段化，此处先 id 映射）。
const presetListIcons = <String, IconData>{
  'list': CupertinoIcons.list_bullet,
  'cart': CupertinoIcons.cart,
  'home': CupertinoIcons.house,
  'work': CupertinoIcons.briefcase,
  'school': CupertinoIcons.book,
  'favorite': CupertinoIcons.heart,
  'flight': CupertinoIcons.airplane,
  'folder': CupertinoIcons.folder,
};

/// 编辑已有列表（#491）：名称 + 颜色 + 类型。
///
/// 图标需要领域字段（ReminderList 无 listIcon），新建弹窗的图标选择也尚未落库，
/// 按对等矩阵行 13 的「图标/类型按图4增强 → M2」后置，这里只改可持久化字段。
Future<void> showEditListDialog(
  BuildContext context, {
  required ReminderList list,
  required Future<void> Function(ReminderList) onSave,
}) {
  final titleController = TextEditingController(text: list.title);
  var colorArgb = list.colorArgb;
  var listType = list.listType;

  const palette = <int>[
    0xFF34C759,
    0xFF007AFF,
    0xFFFF9500,
    0xFFFF3B30,
    0xFFAF52DE,
    0xFFFFCC00,
    0xFF5856D6,
    0xFF30B0C7,
  ];

  return showCupertinoDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => LifeAlertDialog(
        title: const Text('编辑列表'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CupertinoTextField(
                key: const ValueKey('edit_list_name'),
                controller: titleController,
                autofocus: true,
                placeholder: '列表名称',
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      CupertinoColors.tertiarySystemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(LifeRadius.md),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final c in palette)
                    GestureDetector(
                      key: ValueKey('edit_color_$c'),
                      onTap: () => setState(() => colorArgb = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(c),
                        ),
                        child: colorArgb == c
                            ? const Icon(
                                CupertinoIcons.checkmark,
                                size: 16,
                                color: CupertinoColors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              CupertinoSlidingSegmentedControl<ReminderListType>(
                key: const ValueKey('edit_list_type'),
                groupValue: listType,
                children: const {
                  ReminderListType.standard: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('标准', style: TextStyle(fontSize: 13)),
                  ),
                  ReminderListType.grocery: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('日常采购', style: TextStyle(fontSize: 13)),
                  ),
                },
                onValueChanged: (v) => setState(
                  () => listType = v ?? ReminderListType.standard,
                ),
              ),
            ],
          ),
        ),
        actions: [
          LifeDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          LifeDialogAction(
            key: const ValueKey('edit_list_submit'),
            isDefaultAction: true,
            onPressed: () async {
              final name = titleController.text.trim();
              if (name.isEmpty) return;
              await onSave(
                list.copyWith(
                  title: name,
                  colorArgb: colorArgb,
                  listType: listType,
                ),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}
