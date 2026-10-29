import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/calendar_tokens.dart';
import '../logic/lunar_label.dart';
import '../providers.dart';

/// 日程**列表视图**（#399；矩阵 I17）。
///
/// 此前这个视图档只有一个 `Text('列表')` 占位：用户能切过去，但整页空白。
/// Apple 日历的列表视图是按**日期分组**的日程清单（组头日期 + 每行时间/标题/日历色），
/// 这里按同一结构实现，取数窗口为「锚点月往前 1 个月、往后 2 个月」——
/// 足够覆盖用户翻到列表后常见的上下浏览，又不会一次拉全部历史。
class CalendarListView extends ConsumerWidget {
  const CalendarListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchor = ref.watch(anchorDateProvider);
    final from = DateTime(anchor.year, anchor.month - 1, 1);
    final to = DateTime(anchor.year, anchor.month + 3, 1);
    final calendars = ref.watch(calendarsProvider).value ?? const <Calendar>[];
    final byId = {for (final c in calendars) c.id: c};
    final eventsAsync = ref.watch(_listWindowProvider((from, to)));

    final events = eventsAsync.value ?? const <CalendarEvent>[];
    final visibleIds = ref.watch(visibleCalendarIdsProvider);
    final rows = <_ListRow>[];
    for (final event in events) {
      if (visibleIds.isNotEmpty && !visibleIds.contains(event.calendarId)) {
        continue;
      }
      rows.add(_ListRow(
        start: event.startAt,
        allDay: event.allDay,
        title: event.title.isEmpty ? '新建日程' : event.title,
        color: byId[event.calendarId]?.colorArgb ?? 0xFF007AFF,
        event: event,
      ));
    }
    rows.sort((a, b) => a.start.compareTo(b.start));

    if (rows.isEmpty) {
      return Center(
        key: const Key('calendar_list_empty'),
        child: Text(
          '这段时间没有日程',
          style: TextStyle(
            color: CalendarTokens.labelSecondary.resolveFrom(context),
          ),
        ),
      );
    }

    // 按「日」分组：组头是日期（今天额外标出），组内按时间升序。
    final groups = <DateTime, List<_ListRow>>{};
    for (final row in rows) {
      final day = DateTime(row.start.year, row.start.month, row.start.day);
      groups.putIfAbsent(day, () => <_ListRow>[]).add(row);
    }
    final days = groups.keys.toList()..sort();
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);

    return ListView(
      key: const Key('calendar_list_view'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
            child: Row(
              children: [
                Text(
                  _dayLabel(day),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: day == today
                        ? CupertinoColors.systemRed.resolveFrom(context)
                        : CalendarTokens.labelSecondary.resolveFrom(context),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${lunarDayLabel(day)}  ${_weekdayLabel(day)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: CalendarTokens.labelSubtle.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          for (final row in groups[day]!) _ListRowTile(row: row),
        ],
      ],
    );
  }

  static String _dayLabel(DateTime day) => '${day.month}月${day.day}日';

  static String _weekdayLabel(DateTime day) =>
      const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][
          day.weekday - 1];
}

/// 列表窗口的取数（锚点变化时重建；窗口固定 3 个月，避免跨视图频繁重查）。
final _listWindowProvider =
    StreamProvider.family<List<CalendarEvent>, (DateTime, DateTime)>(
        (ref, window) {
  final repo = ref.watch(calendarRepositoryProvider);
  return repo.watchEvents(from: window.$1, to: window.$2);
});

class _ListRow {
  const _ListRow({
    required this.start,
    required this.allDay,
    required this.title,
    required this.color,
    required this.event,
  });

  final DateTime start;
  final bool allDay;
  final String title;
  final int color;
  final CalendarEvent event;
}

class _ListRowTile extends StatelessWidget {
  const _ListRowTile({required this.row});

  final _ListRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              row.allDay
                  ? '全天'
                  : '${row.start.hour.toString().padLeft(2, '0')}:'
                      '${row.start.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: CalendarTokens.labelSecondary.resolveFrom(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 8),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(row.color),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: CalendarTokens.labelStrong.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
