import 'package:flutter/material.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// 新建列表弹窗（名称 + 颜色；对齐提醒事项「新列表」流程）。
///
/// 提交 = [onCreate]（由上层调 upsertList；id 走 [newListId] 工厂）。
Future<void> showNewListDialog(
  BuildContext context, {
  required ValueChanged<ReminderList> onCreate,
}) {
  final titleController = TextEditingController();
  var colorArgb = 0xFF34C759;

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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = titleController.text.trim();
              if (name.isEmpty) return;
              onCreate(ReminderList(
                id: newListId(),
                title: name,
                colorArgb: colorArgb,
              ));
              Navigator.of(context).pop();
            },
            child: const Text('完成'),
          ),
        ],
      ),
    ),
  );
}
