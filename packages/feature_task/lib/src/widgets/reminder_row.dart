import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// 提醒行（Apple 提醒事项样式）：完成圆圈 + 标题 + 日期/旗标/优先级展示。
///
/// 布局无关：紧凑单栏、分栏右栏、三栏中栏共用。
class ReminderRow extends StatelessWidget {
  const ReminderRow({
    super.key,
    required this.item,
    required this.onToggleCompleted,
    this.onTap,
  });

  final ReminderItem item;
  final VoidCallback onToggleCompleted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dueText = _dueText(context, item.dueAt);
    final trailing = <Widget>[
      if (item.isFlagged)
        const Icon(CupertinoIcons.flag_fill, color: Color(0xFFFF9500)),
      if (item.priority > 0)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            _priorityMark(item.priority),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _priorityColor(item.priority),
            ),
          ),
        ),
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: GestureDetector(
        onTap: onToggleCompleted,
        behavior: HitTestBehavior.opaque,
        child: Icon(
          item.isCompleted
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.circle,
          color: item.isCompleted
              ? const Color(0xFF007AFF)
              : const Color(0xFFC7C7CC),
          size: 22,
        ),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          decoration: item.isCompleted ? TextDecoration.lineThrough : null,
          color: item.isCompleted ? const Color(0xFF8E8E93) : null,
          fontSize: 16,
        ),
      ),
      subtitle: dueText == null ? null : Text(dueText),
      subtitleTextStyle: const TextStyle(color: Color(0xFF8E8E93)),
      trailing: trailing.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: trailing),
      onTap: onTap,
    );
  }

  String? _dueText(BuildContext context, DateTime? dueAt) {
    if (dueAt == null) return null;
    final material = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final isToday = dueAt.year == now.year &&
        dueAt.month == now.month &&
        dueAt.day == now.day;
    if (isToday) return '今天';
    return material.formatMediumDate(dueAt);
  }

  static String _priorityMark(int priority) {
    return switch (priority) {
      >= 9 => '!!!',
      >= 5 => '!!',
      _ => '!',
    };
  }

  static Color _priorityColor(int priority) {
    return switch (priority) {
      >= 9 => const Color(0xFFFF3B30),
      >= 5 => const Color(0xFFFF9500),
      _ => const Color(0xFF34C759),
    };
  }
}
