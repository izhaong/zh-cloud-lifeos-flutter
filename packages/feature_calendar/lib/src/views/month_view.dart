import 'dart:ui' show PlatformDispatcher;
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
import '../logic/week_start.dart';
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

  /// #552：表头与正文必须共用**同一个**周起始日与「显示周号」开关，
  /// 所以这两个值在 initState 里定一次（与交给 `MonthViewConfiguration` 的这份同源），
  /// 表头不再向库要日期。
  late final int _firstDayOfWeek;
  late final bool _showWeekNumbers;

  @override
  void initState() {
    super.initState();
    final preference =
        ref.read(preferenceProvider).value ?? CalendarPreference.defaults;
    final anchor = ref.read(anchorDateProvider);
    _firstDayOfWeek = effectiveStartWeekOn(
      preference.startWeekOn,
      // null 时回落系统区域：生产行为与「跟随系统」一致，测试可 override 钉死。
      localeTag:
          ref.watch(calendarLocaleTagProvider) ??
          PlatformDispatcher.instance.locale.toLanguageTag(),
    );
    _showWeekNumbers = preference.showWeekNumbers;
    _controller = kalender.KalenderController(
      viewConfiguration: kalender.MonthViewConfiguration.singleMonth(
        firstDayOfWeek: _firstDayOfWeek,
        showWeekNumbers: _showWeekNumbers,
        initialDateTime: DateTime(anchor.year, anchor.month, 1),
      ),
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
            // #402：月视图用**空心圆**区分提醒事项（Apple 口径），
            // 与普通日程的实心色条形成层级差。
            isReminder: o.source == OccurrenceSource.reminder,
          ),
    ]);

    return KeyedSubtree(
      key: const Key('calendar_month_view'),
      child: LifeMaterialIsland(
        child: kalender.KalenderView(
          eventsController: widget.eventsController,
          kalenderController: _controller,
          // #225：views 不再可 const（双击闸门在 callbacks 上，views 保持纯配置）
          views: [
            kalender.MonthViewParts(
              // #164：原先把表头换成 SizedBox.shrink()，月视图完全没有星期行
              //
              // #552：表头自绘。`kalender.MonthHeader` 的 7 个表头日期是
              // `visibleDateTimeRange.start.add(Duration(days: index))`——绝对时长，
              // 跨美国东部 2026-11-01 的回拨日会给出两个周日、缺一个周六。
              // 星期标签本来就只取决于「周起始日 + 列序号」，所以这里不接受库给的日期，
              // 而与正文共用同一个 firstDayOfWeek / showWeekNumbers（initState 定一次）。
              header: KeyedSubtree(
                key: const Key('month_weekday_header'),
                child: MonthWeekdayHeader(
                  firstDayOfWeek: _firstDayOfWeek,
                  showWeekNumbers: _showWeekNumbers,
                ),
              ),
              body: const kalender.MonthBody(
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
/// #552：月视图星期表头第 i 列（0 基）对应的 ISO 星期序号。
///
/// 纯函数，与进程时区无关 ⇒ 判据在任何机器都成立（库给的日期跨回拨日会重复一天，
/// 而标签本该只由「周起始日 + 列序号」决定）。
List<int> monthWeekdayHeaderIsoWeekdays(int firstDayOfWeek) => [
  for (var i = 0; i < DateTime.daysPerWeek; i++) ((firstDayOfWeek - 1 + i) % 7) + 1,
];

/// ISO 星期序号（1..7）→ 中文单字。
///
/// kalender 默认走 intl，zh 数据未初始化会抛错（英文全名问题见 #193），所以自给。
const List<String> kMonthWeekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

/// #552：星期表头行。列序与配色沿用 #164 定下的口径，但标签不再向库要日期。
class MonthWeekdayHeader extends StatelessWidget {
  const MonthWeekdayHeader({
    super.key,
    required this.firstDayOfWeek,
    required this.showWeekNumbers,
  });

  final int firstDayOfWeek;
  final bool showWeekNumbers;

  @override
  Widget build(BuildContext context) {
    // 与正文同一把尺：kalender 自己的表头用 MonthWeekNumberSpacer，
    // 其宽度解析到 defaultWeekNumberWidth（本仓未设自定义 weekNumberWidth）。
    final gutter = showWeekNumbers
        ? kalender.defaultWeekNumberWidth(context)
        : 0.0;
    return Row(
      children: [
        if (showWeekNumbers) SizedBox(width: gutter),
        Expanded(
          child: Row(
            children: [
              for (final iso in monthWeekdayHeaderIsoWeekdays(firstDayOfWeek))
                Expanded(
                  child: Padding(
                    key: ValueKey('month_weekday_$iso'),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: Text(
                        kMonthWeekdayNames[iso - 1],
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              (iso == DateTime.saturday ||
                                  iso == DateTime.sunday)
                              ? CalendarTokens.labelSecondary
                              : CalendarTokens.labelSubtle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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
  if (tile?.isReminder == true) {
    // #402：Apple 月视图里提醒是**空心圆 + 文字**，不是色条——一眼能和日程分开。
    return Container(
      key: Key('month-reminder-${tile!.kernelEventId}'),
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              tile.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }
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
    this.isReminder = false,
  });

  final String kernelEventId;
  final int colorArgb;
  final String title;

  /// 该 tile 是不是「提醒事项」投影（#402）：决定月视图里画实心条还是空心圆。
  final bool isReminder;

  @override
  CalendarEventTile copyWithData({
    required DateTime start,
    required DateTime end,
  }) {
    return CalendarEventTile(
      isReminder: isReminder,
      start: start,
      end: end,
      kernelEventId: kernelEventId,
      colorArgb: colorArgb,
      title: title,
    );
  }
}
