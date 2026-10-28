import '../design/calendar_tokens.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart' as kalender;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../providers.dart';

/// 日视图右侧提醒栏（契约 §5.4；Key `day_reminder_lane`；F-15 / #181）。
///
/// 展示锚点当天的定时提醒：时间 + 空心圆 + 标题（Apple 日程侧栏同款）。
/// 已完成项删除线；无提醒时给出空态。
class DayReminderLane extends ConsumerWidget {
  const DayReminderLane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchor = ref.watch(anchorDateProvider);
    final showReminders = ref.watch(scheduledRemindersVisibleProvider);
    final items = showReminders
        ? (ref.watch(reminderItemsForCalendarProvider).value ??
            const <ReminderItem>[])
        : const <ReminderItem>[];

    final day = DateTime(anchor.year, anchor.month, anchor.day);
    final todays = items
        .where((e) => e.deletedAt == null)
        .where((e) {
          final due = e.dueAt;
          if (due == null) return false;
          return due.year == day.year &&
              due.month == day.month &&
              due.day == day.day;
        })
        .toList(growable: false)
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    return Container(
      key: const Key('day_reminder_lane'),
      color: CalendarTokens.windowBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              '提醒事项',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CalendarTokens.labelSecondary,
              ),
            ),
          ),
          Expanded(
            child: todays.isEmpty
                ? const Center(
                    key: Key('day_reminder_lane_empty'),
                    child: Text(
                      '没有提醒事项',
                      style: TextStyle(
                        fontSize: 12,
                        color: CalendarTokens.grey3,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final item in todays)
                        _LaneReminderRow(item: item),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _LaneReminderRow extends StatelessWidget {
  const _LaneReminderRow({required this.item});

  final ReminderItem item;

  @override
  Widget build(BuildContext context) {
    final due = item.dueAt!;
    final allDay = due.hour == 0 && due.minute == 0;
    final time = allDay
        ? '全天'
        : '${due.hour.toString().padLeft(2, '0')}:'
            '${due.minute.toString().padLeft(2, '0')}';
    return Container(
      key: ValueKey('lane_reminder_${item.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Row(
        children: [
          const _HollowCircle(size: 12),
          const SizedBox(width: 6),
          SizedBox(
            width: 42,
            child: Text(
              time,
              style: const TextStyle(fontSize: 11, color: CalendarTokens.labelSecondary),
            ),
          ),
          Expanded(
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: CalendarTokens.labelSubtle,
                decoration:
                    item.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Apple 日程里的提醒以空心圆呈现（非实心事件块）。
class _HollowCircle extends StatelessWidget {
  const _HollowCircle({this.size = 12});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: CalendarTokens.systemBlue, width: 1.5),
      ),
    );
  }
}

/// 时间轴上的提醒标记（#181）：空心圆 + 标题，替代默认事件块。
class ReminderMarkerEvent extends kalender.KalenderEvent {
  ReminderMarkerEvent({
    super.id,
    required super.start,
    required super.end,
    super.isAllDay = false,
    required this.reminderId,
    required this.colorArgb,
    required this.title,
    required this.completed,
  });

  final String reminderId;
  final int colorArgb;
  final String title;
  final bool completed;

  @override
  ReminderMarkerEvent copyWithData({
    required DateTime start,
    required DateTime end,
  }) {
    return ReminderMarkerEvent(
      id: id,
      start: start,
      end: end,
      isAllDay: isAllDay,
      reminderId: reminderId,
      colorArgb: colorArgb,
      title: title,
      completed: completed,
    );
  }
}

/// 时间轴提醒标记的视觉（#181）：空心圆 + 标题，已完成删除线。
Widget buildReminderMarker(ReminderMarkerEvent event) {
  return Container(
    key: Key('reminder_marker_${event.reminderId}'),
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.only(left: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _HollowCircle(),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            event.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Color(event.colorArgb),
              decoration:
                  event.completed ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    ),
  );
}
