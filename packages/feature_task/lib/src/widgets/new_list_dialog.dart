import 'package:flutter/material.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// 新建列表弹窗（名称 + 颜色 + 图标 + 类型；图4 全字段，TC-UI-115/316）。
///
/// - 类型：标准 / 日常采购（grocery 预置 8 分区模板，不做商品识别——HT105086 降级）
/// - 图标：8 个 Material Symbols 预设（列表头展示用）
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

  return showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('新列表'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(hintText: '列表名称'),
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
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(c),
                      child: colorArgb == c
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 图标选择（TC-UI-316 图4 字段）
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in presetListIcons.entries)
                  GestureDetector(
                    key: ValueKey('icon_${entry.key}'),
                    onTap: () => setState(() => iconId = entry.key),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: iconId == entry.key
                          ? Color(colorArgb)
                          : const Color(0xFFF2F2F7),
                      child: Icon(entry.value,
                          size: 18,
                          color: iconId == entry.key
                              ? Colors.white
                              : const Color(0xFF8E8E93)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 类型下拉（TC-UI-313：标准 / 日常采购；智能列表入口后置 TC-UI-116）
            DropdownButtonFormField<ReminderListType>(
              key: const ValueKey('list_type'),
              initialValue: listType,
              decoration: const InputDecoration(
                labelText: '类型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: ReminderListType.standard,
                  child: Text('标准'),
                ),
                DropdownMenuItem(
                  value: ReminderListType.grocery,
                  child: Text('日常采购（预置分区）'),
                ),
              ],
              onChanged: (v) => setState(() => listType = v!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('new_list_submit'),
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
  'list': Icons.list,
  'cart': Icons.shopping_cart_outlined,
  'home': Icons.home_outlined,
  'work': Icons.work_outline,
  'school': Icons.school_outlined,
  'favorite': Icons.favorite_border,
  'flight': Icons.flight_outlined,
  'folder': Icons.folder_outlined,
};
