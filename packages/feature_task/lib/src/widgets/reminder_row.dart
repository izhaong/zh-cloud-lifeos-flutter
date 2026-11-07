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
    this.now,
    required this.onToggleCompleted,
    this.onToggleFlagged,
    this.onTap,
    this.onDelete,
    this.onSetPriority,
    this.dense = false,
    this.listName,
    this.subtaskDone = 0,
    this.subtaskTotal = 0,
    this.allDayAsOverdue = false,
  });

  final ReminderItem item;

  /// 「现在」（由 [clockProvider] 注入；生产=null 即取挂钟，测试=固定时刻）。
  /// #333 审查指出：这里原先直接 `DateTime.now()`，导致到期/过期文案与样式
  /// 不跟注入时钟，golden 跨日会漂。
  final DateTime? now;

  /// 全天提醒是否按逾期显示（#446；由设置项经调用方传入，默认 false）。
  final bool allDayAsOverdue;

  final String? listName;
  final VoidCallback onToggleCompleted;
  final VoidCallback? onToggleFlagged;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// 右键菜单「优先级」（值同详情面板：0 无 / 1 低 / 5 中 / 9 高）；null = 不列。
  final ValueChanged<int>? onSetPriority;

  /// 子任务行的紧凑变体（缩进由外层控制）。
  final bool dense;

  /// 子任务进度（parity#166：Apple 在父行显示 `1/2`；总数 0 = 不显示）。
  final int subtaskDone;
  final int subtaskTotal;

  @override
  Widget build(BuildContext context) {
    final due = _dueText(context, item.dueAt);
    final meta = <String>[
      if (subtaskTotal > 0) '$subtaskDone/$subtaskTotal',
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
    // parity#205：列表名与到期日都解析成「今天」时不重复拼接。
    if (due != null && due.text != listName) {
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
                    ? ReminderTokens.systemBlue
                    : CupertinoColors.systemGrey3,
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
                      style: TextStyle(
                        color: CupertinoDynamicColor.resolve(ReminderTokens.labelSecondary, context),
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
                        ? ReminderTokens.systemOrange
                        : CupertinoColors.systemGrey3,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    final body = onDelete == null
        ? tile
        : Dismissible(
            key: ValueKey('dismiss_${item.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: ReminderTokens.systemRed,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(
                CupertinoIcons.delete,
                color: CupertinoColors.white,
              ),
            ),
            onDismissed: (_) => onDelete!(),
            child: tile,
          );
    // #675：右键（Control 点按）弹锚定在光标处的桌面上下文菜单，
    // 不再是贴底的移动端操作表、也不只剩「删除」一项。
    return CupertinoMenuAnchor(
      menuChildren: _contextMenuItems(),
      builder: (context, controller, child) => GestureDetector(
        key: ValueKey('row_context_${item.id}'),
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (details) =>
            controller.open(position: details.localPosition),
        child: child,
      ),
      child: body,
    );
  }

  static const _priorityLabels = <int, String>{
    0: '无',
    1: '低',
    5: '中',
    9: '高',
  };

  List<Widget> _contextMenuItems() {
    final id = item.id;
    return [
      CupertinoMenuItem(
        key: ValueKey('row_ctx_complete_$id'),
        onPressed: onToggleCompleted,
        child: Text(item.isCompleted ? '标记为未完成' : '标记为完成'),
      ),
      if (onToggleFlagged != null)
        CupertinoMenuItem(
          key: ValueKey('row_ctx_flag_$id'),
          onPressed: onToggleFlagged,
          child: Text(item.isFlagged ? '取消旗标' : '旗标'),
        ),
      if (onSetPriority != null) ...[
        const CupertinoMenuDivider(),
        for (final entry in _priorityLabels.entries)
          CupertinoMenuItem(
            key: ValueKey('row_ctx_priority_${entry.key}_$id'),
            onPressed: () => onSetPriority!(entry.key),
            trailing: entry.key == item.priority
                ? const Icon(CupertinoIcons.checkmark, size: 14)
                : null,
            child: Text('优先级：${entry.value}'),
          ),
      ],
      if (onTap != null) ...[
        const CupertinoMenuDivider(),
        CupertinoMenuItem(
          key: ValueKey('row_ctx_info_$id'),
          onPressed: onTap,
          child: const Text('显示简介'),
        ),
      ],
      if (onDelete != null) ...[
        const CupertinoMenuDivider(),
        CupertinoMenuItem(
          key: ValueKey('row_ctx_delete_$id'),
          isDestructiveAction: true,
          onPressed: onDelete,
          child: const Text('删除'),
        ),
      ],
    ];
  }

  ({String text, bool overdue})? _dueText(
    BuildContext context,
    DateTime? dueAt,
  ) {
    if (dueAt == null) return null;
    final locale = Localizations.localeOf(context).toString();
    final now = this.now ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // #446：全天提醒（时分秒为 0）默认**不**标逾期——过期只在日期上体现；
    // 打开「将全天提醒显示为逾期」后与定时提醒同待遇。
    final isAllDay = dueAt.hour == 0 && dueAt.minute == 0 && dueAt.second == 0;
    if (isAllDay && !allDayAsOverdue) {
      if (dueAt.isBefore(today)) {
        return (text: DateFormat.MMMd(locale).format(dueAt), overdue: false);
      }
    }
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
      >= 9 => ReminderTokens.systemRed,
      >= 5 => ReminderTokens.systemOrange,
      _ => ReminderTokens.systemGreen,
    };
  }
}
