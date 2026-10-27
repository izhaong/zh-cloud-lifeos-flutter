import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:intl/intl.dart';

import '../design/reminder_tokens.dart';

/// 提醒行（Apple 提醒事项样式）：完成圆圈 + 标题 + 列表名/日期/旗标/优先级展示。
///
/// 布局无关：紧凑单栏、分栏右栏、三栏中栏共用；
/// 旗标可点击即时切换（detail 编辑走 copyWith + upsertItem 全量回写）。
class ReminderRow extends StatelessWidget {
  const ReminderRow({
    super.key,
    required this.item,
    required this.onToggleCompleted,
    this.onToggleFlagged,
    this.onTap,
    this.onDelete,
    this.dense = false,
    this.listName,
  });

  final ReminderItem item;
  final String? listName;
  final VoidCallback onToggleCompleted;
  final VoidCallback? onToggleFlagged;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// 子任务行的紧凑变体（缩进由外层控制）。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final due = _dueText(context, item.dueAt);
    final meta = <String>[
      if (item.recurrence != null) _recurrenceLabel(item.recurrence!),
      if (item.tags.isNotEmpty) item.tags.join(' '),
    ];
    final spans = <InlineSpan>[];
    void addSeparator() {
      if (spans.isNotEmpty) spans.add(const TextSpan(text: ' · '));
    }

    if (listName != null && listName!.isNotEmpty) {
      spans.add(TextSpan(text: listName));
    }
    if (due != null) {
      addSeparator();
      spans.add(TextSpan(
        text: due.text,
        style: due.overdue
            ? const TextStyle(color: ReminderTokens.systemRed)
            : null,
      ));
    }
    for (final m in meta) {
      addSeparator();
      spans.add(TextSpan(text: m));
    }

    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: dense ? 36 : 48),
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: dense ? 4 : 6,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggleCompleted,
              behavior: HitTestBehavior.opaque,
              child: Icon(
                item.isCompleted
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                color: item.isCompleted
                    ? const Color(0xFF007AFF)
                    : const Color(0xFFC7C7CC),
                size: dense ? 18 : 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      decoration:
                          item.isCompleted ? TextDecoration.lineThrough : null,
                      color: item.isCompleted
                          ? CupertinoColors.secondaryLabel.resolveFrom(context)
                          : CupertinoColors.label.resolveFrom(context),
                      fontSize: dense ? 14 : 16,
                    ),
                  ),
                  if (spans.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: spans),
                      style: const TextStyle(
                        color: ReminderTokens.labelSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.priority > 0)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  _priorityMark(item.priority),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _priorityColor(item.priority),
                  ),
                ),
              ),
            if (onToggleFlagged != null)
              GestureDetector(
                key: ValueKey('row_flag_${item.id}'),
                onTap: onToggleFlagged,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    item.isFlagged
                        ? CupertinoIcons.flag_fill
                        : CupertinoIcons.flag,
                    color: item.isFlagged
                        ? const Color(0xFFFF9500)
                        : const Color(0xFFC7C7CC),
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (onDelete == null) return tile;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTap: () => _showDeleteMenu(context),
      child: Dismissible(
        key: ValueKey('dismiss_${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          color: ReminderTokens.systemRed,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
        ),
        onDismissed: (_) => onDelete!(),
        child: tile,
      ),
    );
  }

  Future<void> _showDeleteMenu(BuildContext context) async {
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: const Text('删除提醒'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == 'delete') onDelete?.call();
  }

  ({String text, bool overdue})? _dueText(
    BuildContext context,
    DateTime? dueAt,
  ) {
    if (dueAt == null) return null;
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (dueAt.isBefore(today)) {
      return (
        text: DateFormat.MMMd(locale).format(dueAt),
        overdue: true,
      );
    }
    final isToday = dueAt.year == now.year &&
        dueAt.month == now.month &&
        dueAt.day == now.day;
    if (isToday) {
      if (dueAt.hour != 0 || dueAt.minute != 0) {
        final hh = dueAt.hour.toString().padLeft(2, '0');
        final mm = dueAt.minute.toString().padLeft(2, '0');
        return (text: '$hh:$mm', overdue: false);
      }
      return (text: '今天', overdue: false);
    }
    return (text: DateFormat.MMMd(locale).format(dueAt), overdue: false);
  }

  static String _recurrenceLabel(String id) {
    return switch (id) {
      'daily' => '每天',
      'weekly' => '每周',
      'weekdays' => '工作日',
      'monthly' => '每月',
      'yearly' => '每年',
      _ => '重复',
    };
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
