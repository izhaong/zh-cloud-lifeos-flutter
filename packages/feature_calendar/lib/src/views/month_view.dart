import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart' as kalender;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../calendar_view_callbacks.dart';
import '../logic/lunar_label.dart';
import '../providers.dart';

/// 月视图（契约 §5.4；F-06）。
///
/// 全天与定时都显示色条（色=日历颜色，TC-CAL-UI-112）；格内日期下显示农历日
/// （alternateCalendar=CHINESE，初一红色，TC-CAL-UI-115）；点/双击日创建全天草稿
/// （TC-CAL-UI-131，标题交 F-12 解析器）。Key：`calendar_month_view`。
class CalendarMonthView extends ConsumerStatefulWidget {
  const CalendarMonthView({
    super.key,
    required this.viewCallbacks,
    required this.eventsController,
  });

  final CalendarViewCallbacks viewCallbacks;
  final kalender.DefaultEventsController eventsController;

  @override
  ConsumerState<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends ConsumerState<CalendarMonthView> {
  late final kalender.KalenderController _controller;

  @override
  void initState() {
    super.initState();
    final preference =
        ref.read(preferenceProvider).value ?? CalendarPreference.defaults;
    final anchor = ref.read(anchorDateProvider);
    _controller = kalender.KalenderController(
      viewConfiguration: _configFor(preference, anchor),
    );
  }

  static kalender.MonthViewConfiguration _configFor(
    CalendarPreference preference,
    DateTime anchor,
  ) {
    return kalender.MonthViewConfiguration.singleMonth(
      firstDayOfWeek: preference.startWeekOn == 7
          ? DateTime.sunday
          : DateTime.monday,
      showWeekNumbers: preference.showWeekNumbers,
      initialDateTime: DateTime(anchor.year, anchor.month, 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preference =
        ref.watch(preferenceProvider).value ?? CalendarPreference.defaults;
    final chinese = preference.alternateCalendar == AlternateCalendar.chinese;

    // 页面切换 → 同步锚点（工具栏/迷你月历与月视图一致）。
    void onPageChanged(kalender.KalenderDateTimeRange range) {
      final start = range.start.toUtc();
      ref
          .read(anchorDateProvider.notifier)
          .set(DateTime(start.year, start.month, start.day));
    }

    // occurrence → kalender 事件装载（重叠/跨周布局由库处理）。
    final occurrences =
        ref.watch(occurrencesProvider(_visibleMonthRange())).value ??
        const <CalendarOccurrence>[];
    widget.eventsController.replaceEvents([
      for (final o in occurrences)
        if (o.source != OccurrenceSource.holiday)
          CalendarEventTile(
            id: '${o.eventId}:${o.start.microsecondsSinceEpoch}',
            start: o.start.toUtc(),
            end: o.end.toUtc(),
            isAllDay: o.allDay,
            kernelEventId: o.eventId,
            colorArgb: o.colorArgb,
            title: o.title,
          ),
    ]);

    return KeyedSubtree(
      key: const Key('calendar_month_view'),
      child: LifeMaterialIsland(
        child: kalender.KalenderView(
          eventsController: widget.eventsController,
          kalenderController: _controller,
          views: const [
            kalender.MonthViewParts(
              header: SizedBox.shrink(),
              body: kalender.MonthBody(
                tileComponents: kalender.TileComponents(
                  tileBuilder: monthEventTileBuilder,
                ),
              ),
            ),
          ],
          components: kalender.KalenderComponents(
            monthComponents: kalender.MonthComponents(
              bodyComponents: kalender.MonthBodyComponents(
                monthDayHeaderBuilder: (context, date) =>
                    _MonthDayHeader(date: date, chinese: chinese),
              ),
            ),
          ),
          callbacks: kalender.KalenderCallbacks(
            onPageChanged: onPageChanged,
            onTapped: (date) => widget.viewCallbacks.onDayTap(date),
            onEventCreate: (event) {
              widget.viewCallbacks.onDayTap(event.start);
              return event;
            },
            onEventTapped: (event) {
              for (final o in occurrences) {
                if (event.id.startsWith('${o.eventId}:')) {
                  widget.viewCallbacks.onOccurrenceTapped(o);
                  break;
                }
              }
            },
            onEventSecondaryTapped: (event) {
              for (final o in occurrences) {
                if (event.id.startsWith('${o.eventId}:')) {
                  if (o.source == OccurrenceSource.reminder) {
                    confirmDeleteReminder(context, widget.viewCallbacks, o);
                  }
                  break;
                }
              }
            },
          ),
        ),
      ),
    );
  }

  /// 当前月可视窗口（含跨月溢出前后各一周，保证边缘格事件可见）。
  (DateTime, DateTime) _visibleMonthRange() {
    final anchor = ref.watch(anchorDateProvider);
    final monthStart = DateTime(anchor.year, anchor.month, 1);
    final monthEnd = DateTime(anchor.year, anchor.month + 1, 1);
    return (
      monthStart.subtract(const Duration(days: 7)),
      monthEnd.add(const Duration(days: 7)),
    );
  }
}

/// 月格日期头：日期数字 +（CHINESE 时）农历日；初一红色（TC-CAL-UI-115）。
class _MonthDayHeader extends StatelessWidget {
  const _MonthDayHeader({required this.date, required this.chinese});

  final DateTime date;
  final bool chinese;

  @override
  Widget build(BuildContext context) {
    if (!chinese) {
      return Padding(
        padding: const EdgeInsets.all(2),
        child: Text('${date.day}'),
      );
    }
    final label = lunarDayLabel(date);
    final isFirst = isLunarFirstDay(date);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${date.day}'),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isFirst
                  ? const Color(0xFFFF3B30)
                  : const Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }
}

/// 色条 tile（色=日历颜色；文本=标题；TC-CAL-UI-112）。
Widget monthEventTileBuilder(
  BuildContext context,
  kalender.KalenderEvent event,
  kalender.KalenderDateTimeRange tileRange,
) {
  final tile = event is CalendarEventTile ? event : null;
  final color = Color(tile?.colorArgb ?? 0xFF007AFF);
  return Container(
    key: Key('month-event-${tile?.kernelEventId ?? event.id}'),
    margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(60),
      borderRadius: BorderRadius.circular(4),
      border: BorderDirectional(start: BorderSide(width: 3, color: color)),
    ),
    alignment: Alignment.centerLeft,
    child: Text(
      tile?.title ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, color: color),
    ),
  );
}

/// 携带展示数据的 kalender 事件（库支持子类附加数据）。
class CalendarEventTile extends kalender.KalenderEvent {
  CalendarEventTile({
    super.id,
    required super.start,
    required super.end,
    super.isAllDay = false,
    required this.kernelEventId,
    required this.colorArgb,
    required this.title,
  });

  final String kernelEventId;
  final int colorArgb;
  final String title;

  @override
  CalendarEventTile copyWithData({
    required DateTime start,
    required DateTime end,
  }) {
    return CalendarEventTile(
      start: start,
      end: end,
      kernelEventId: kernelEventId,
      colorArgb: colorArgb,
      title: title,
    );
  }
}
