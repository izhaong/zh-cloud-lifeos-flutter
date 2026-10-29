import 'package:app_ui/app_ui.dart';
import '../design/calendar_tokens.dart';
import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart' as kalender;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../calendar_view_callbacks.dart';
import '../logic/double_tap_create.dart';
import '../logic/lunar_label.dart';
import '../providers.dart';

/// #225：月视图双击闸门（页面级单实例；跨 build 保留节拍）。
final _monthTapGate = CalendarTapGate();

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
          // #225：views 不再可 const（双击闸门在 callbacks 上，views 保持纯配置）
          views: const [
            kalender.MonthViewParts(
              // #164：原先把表头换成 SizedBox.shrink()，月视图完全没有星期行
              header: KeyedSubtree(
                key: Key('month_weekday_header'),
                child: kalender.MonthHeader(),
              ),
              body: kalender.MonthBody(
                tileComponents: kalender.TileComponents(
                  tileBuilder: monthEventTileBuilder,
                ),
              ),
            ),
          ],
          components: kalender.KalenderComponents(
            monthComponents: kalender.MonthComponents(
              // 星期名固定用中文单字（kalender 默认走 intl，zh 数据未初始化会抛错；
              // 英文全名问题见 #193）
              headerComponents: kalender.MonthHeaderComponents(
                weekDayHeaderBuilder: (context, date) =>
                    _MonthWeekDayHeader(date: date),
              ),
              bodyComponents: kalender.MonthBodyComponents(
                monthDayHeaderBuilder: (context, date) =>
                    _MonthDayHeader(
                      date: date,
                      chinese: chinese,
                      today: ref.watch(clockProvider)(),
                    ),
              ),
            ),
          ),
          callbacks: kalender.KalenderCallbacks(
            onPageChanged: onPageChanged,
            // #225：月格空区单击即创建全天草稿（既有口径，TC-CAL-UI-131）；
            // 双击的第二下必须吞掉，否则会落在草稿弹层遮罩上把草稿关掉。
            onTapped: (date) {
              if (_monthTapGate.allow(date)) {
                widget.viewCallbacks.onDayTap(date);
              }
            },
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

/// 月格日期头：日期数字 +（CHINESE 时）农历日；初一红色（TC-CAL-UI-115）；
/// 当天（本地日）用红底白字圆点标记（#164）。
class _MonthDayHeader extends StatelessWidget {
  const _MonthDayHeader({
    required this.date,
    required this.chinese,
    required this.today,
  });

  final DateTime date;
  final bool chinese;

  /// 「今天」（由 [clockProvider] 注入，生产=挂钟，测试=固定时刻）。
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final number = Container(
      key: isToday ? const Key('month-today') : null,
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: isToday
          ? BoxDecoration(
              // #304：paint 通道不解算动态色，暗色档会画亮档红
              color: CupertinoColors.systemRed.resolveFrom(context),
              shape: BoxShape.circle,
            )
          : null,
      child: Text(
        '${date.day}',
        style: TextStyle(
          // 红圈上的字必须恒为白（surface 在暗色下是深色，会造成红底深字）
          color: isToday ? CupertinoColors.white : null,
          fontWeight: isToday ? FontWeight.w600 : null,
        ),
      ),
    );
    if (!chinese) {
      return Padding(
        padding: const EdgeInsets.all(2),
        child: number,
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
          number,
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isFirst
                  ? CalendarTokens.systemRed
                  : CalendarTokens.labelSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 月视图星期行：中文单字，周末灰色（Apple 月视图同款）。
class _MonthWeekDayHeader extends StatelessWidget {
  const _MonthWeekDayHeader({required this.date});

  final DateTime date;

  static const _names = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final isWeekend = date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday;
    return Padding(
      key: ValueKey('month_weekday_${date.weekday}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Text(
          _names[date.weekday - 1],
          style: TextStyle(
            fontSize: 12,
            color: isWeekend
                ? CalendarTokens.labelSecondary
                : CalendarTokens.labelSubtle,
          ),
        ),
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
      borderRadius: BorderRadius.circular(LifeRadius.xs),
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
