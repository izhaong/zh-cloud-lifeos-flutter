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
import 'day_reminder_lane.dart';
import 'month_view.dart' show CalendarEventTile;

/// 日视图双击创建节拍器（#225；页面内单实例，跨 build 保节拍）。
final _dayTapTracker = CalendarDoubleTapTracker();

/// 周视图双击创建节拍器（#225）。
final _weekTapTracker = CalendarDoubleTapTracker();

/// 全天带容器（#240）：在 kalender 的 MultiDayHeader 下沿补一条发丝线。
///
/// 空态（没有任何全天/跨日事件）时 kalender 仍会占位（tileHeight×2），但没有
/// 任何可见边界，用户会把这块空白当成定时网格的一部分，于是「往全天区拖」这个
/// 手势没有落点。分隔线只是视觉锚点，不改命中区（拖拽仍由 kalender 处理）。
class _AllDayBand extends StatelessWidget {
  const _AllDayBand({required this.child, this.label});

  final Widget child;

  /// #406：日视图在带首补「全天」标签（Apple 日历全天行）；周视图暂不传。
  final String? label;

  @override
  Widget build(BuildContext context) {
    final content = label == null
        ? child
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
                child: Text(label!,
                    style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context))),
              ),
              child,
            ],
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: content,
    );
  }
}

/// 日视图大标题（#406，对齐 Apple 日历）：
/// 「2026年10月29日」+ 星期 + 农历（丙午年九月十八）。
class _DayViewHeader extends StatelessWidget {
  const _DayViewHeader({required this.date});

  final DateTime date;

  static const _weekdays = [
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final label = CupertinoColors.label.resolveFrom(context);
    final dateText = '${date.year}年${date.month}月${date.day}日';
    final weekdayText = _weekdays[date.weekday - 1];
    final lunarText = lunarDateLabel(date);
    return Padding(
      key: const Key('day_view_header'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 紧凑档（iPhone 375）放不下一行：日期独占一行，星期与农历下一行。
          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateText,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: label)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(weekdayText,
                        style: TextStyle(fontSize: 12, color: secondary)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(lunarText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: secondary)),
                    ),
                  ],
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(dateText,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: label)),
              const SizedBox(width: 10),
              Text(weekdayText,
                  style: TextStyle(fontSize: 15, color: secondary)),
              const Spacer(),
              Flexible(
                child: Text(lunarText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: secondary)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 日视图（契约 §5.4/§8.3；F-05）。
///
/// kalender singleDay 配置；纵轴随偏好 dayStartHour/dayEndHour（TC-CAL-UI-106）；
/// 右侧提醒栏 Key `day_reminder_lane`（F-15 填充）。
/// Key：`calendar_day_view`。
class CalendarDayView extends ConsumerWidget {
  const CalendarDayView({
    super.key,
    required this.viewCallbacks,
    required this.eventsController,
    this.showReminderLane = true,
  });

  final CalendarViewCallbacks viewCallbacks;
  final kalender.DefaultEventsController eventsController;

  /// #185：右栏是宽档特性；紧凑档由外壳传 false（叶子组件不读断点）。
  final bool showReminderLane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(calendarViewConfigurationsProvider);
    final anchor = ref.watch(anchorDateProvider);
    final occurrences =
        ref
            .watch(
              occurrencesProvider((
                anchor,
                anchor.add(const Duration(days: 1)),
              )),
            )
            .value ??
        const [];

    // occurrence → kalender 事件装载（重叠布局由库处理）
    // #197：装载必须延后到帧末——build 期 clearEvents/addEvents 会同步 notify
    // 尚在树中的 kalender 事件 widget（含本帧已 deactivated 的），触发
    // dependOnInherited 异常并中断整棵 build（第三栏 Inspector 挂不上）。
    final loadedEvents = [
      for (final o in occurrences)
          if (o.source == OccurrenceSource.reminder)
            ReminderMarkerEvent(
              id: '${o.eventId}:${o.start.microsecondsSinceEpoch}',
              start: o.start.toUtc(),
              end: o.end.toUtc(),
              isAllDay: o.allDay,
              reminderId: o.reminderId ?? o.eventId,
              colorArgb: o.colorArgb,
              title: o.title,
              completed: o.completed,
            )
          else
          CalendarEventTile(
            id: '${o.eventId}:${o.start.microsecondsSinceEpoch}',
            start: o.start.toUtc(),
            end: o.end.toUtc(),
            isAllDay: o.allDay,
            kernelEventId: o.eventId,
            colorArgb: o.colorArgb,
            title: o.title,
          ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      eventsController.clearEvents();
      eventsController.addEvents(loadedEvents);
    });

    final controller = kalender.KalenderController(
      viewConfiguration: kalender.MultiDayViewConfiguration.singleDay(
        // 表头/网格跟随锚点（#168：未传时 kalender 恒取 now）
        initialDateTime: anchor,
        timeOfDayRange: kalender.KalenderTimeRange(
          start: kalender.KalenderTime(hour: config.day.startHour, minute: 0),
          end: kalender.KalenderTime(hour: config.day.endHour - 1, minute: 59),
        ),
      ),
    );

    return KeyedSubtree(
      key: const Key('calendar_day_view'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DayViewHeader(date: anchor),
                Expanded(
                  child: LifeMaterialIsland(
                    child: kalender.KalenderView(
                      eventsController: eventsController,
                      kalenderController: controller,
                // #193：kalender 默认用自己的 locale（null→intl 默认 en_US），
                // 不传会把中文界面的星期名渲染成 Mon…Sun
                      locale: Localizations.localeOf(context),
                      // #406：日期由外部大标题承载，隐藏 kalender 小徽标。
                      components: kalender.KalenderComponents(
                        multiDayComponents: kalender.MultiDayComponents(
                          headerComponents: kalender.MultiDayHeaderComponents(
                            dayHeaderBuilder: (context, date) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                // #184：显式传 tileComponents，避免 kalender 默认「Tile」占位文案；
                // header（全天/跨日条）与 body（定时条）都要传——审查 R1 意见
                views: const [
                  kalender.MultiDayViewParts(
                    // #240：全天带即使空着也要有下沿分隔线，否则用户看不出
                    // 表头下这块是可拖拽/双击的全天区。
                    // #406：「全天」标签由带首承载（Apple 日历全天行）。
                    header: _AllDayBand(
                      label: '全天',
                      child: kalender.MultiDayHeader(
                        tileComponents: kalender.TileComponents(
                          tileBuilder: dayEventTileBuilder,
                        ),
                      ),
                    ),
                    body: kalender.MultiDayBody(
                      tileComponents: kalender.TileComponents(
                        tileBuilder: dayEventTileBuilder,
                      ),
                    ),
                  ),
                ],
                callbacks: kalender.KalenderCallbacks(
                  // #225：空区双击创建（Apple：Day 视图双击定时区建日程）。
                  // kalender 无双击识别器，用 onTappedWithDetail 上报 +
                  // 节拍器合成双击；DayDetail.date 已含像素→时刻换算与吸附。
                  onTappedWithDetail: (detail) => handleCalendarTapCreate(
                    detail,
                    _dayTapTracker,
                    onDraftCreate: viewCallbacks.onDraftCreate,
                    onDayTap: viewCallbacks.onDayTap,
                  ),
                  // parity#228 + #240：拖拽创建的分派（全天区 / 跨多日 / 同日）
                  // 集中在回调里，两个视图共用同一判据。
                  onEventCreate: (event) {
                    viewCallbacks.onDragCreate(
                      event.start.toLocal(),
                      event.end.toLocal(),
                    );
                    return event;
                  },
                  onEventChanged: (event, updated) {
                    final original = _findOriginal(occurrences, updated.id);
                    viewCallbacks.onEventMoved(
                      original ?? _toKernel(updated),
                      updated.start,
                      updated.end,
                    );
                  },
                  // F-10：点已有日程 → Inspector（带该次 occurrence 起点）
                  onEventTapped: (event) {
                    final occurrence = _findOccurrence(occurrences, event.id);
                    if (occurrence != null) {
                      viewCallbacks.onOccurrenceTapped(occurrence);
                    }
                  },
                  onEventSecondaryTapped: (event) {
                    final occurrence = _findOccurrence(occurrences, event.id);
                    if (occurrence != null &&
                        occurrence.source == OccurrenceSource.reminder) {
                      confirmDeleteReminder(context, viewCallbacks, occurrence);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    ),
          if (showReminderLane) ...[
            Container(
              width: 1,
              color: CalendarTokens.separator.resolveFrom(context),
            ),
            const SizedBox(width: 220, child: DayReminderLane()),
          ],
        ],
      ),
    );
  }

  CalendarOccurrence? _findOccurrence(
    List<CalendarOccurrence> occurrences,
    String kalenderEventId,
  ) {
    for (final o in occurrences) {
      if (kalenderEventId.startsWith('${o.eventId}:')) {
        return o;
      }
    }
    return null;
  }

  CalendarEvent? _findOriginal(
    List<CalendarOccurrence> occurrences,
    String kalenderEventId,
  ) {
    for (final o in occurrences) {
      if (kalenderEventId.startsWith('${o.eventId}:')) {
        return CalendarEvent(
          id: o.eventId,
          calendarId: o.calendarId,
          uid: o.eventId,
          title: o.title,
          startAt: o.start.toUtc(),
          endAt: o.end.toUtc(),
          allDay: o.allDay,
          timeZone: 'UTC',
          updatedAt: DateTime.now().toUtc(),
        );
      }
    }
    return null;
  }
}

/// 周视图（契约 §8.3；F-05）。
///
/// weekViewDays=7 → week；=5 → workWeek（无周六日，TC-CAL-UI-105）。
/// Key：`calendar_week_view`。
class CalendarWeekView extends ConsumerWidget {
  const CalendarWeekView({
    super.key,
    required this.viewCallbacks,
    required this.eventsController,
  });

  final CalendarViewCallbacks viewCallbacks;
  final kalender.DefaultEventsController eventsController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(calendarViewConfigurationsProvider);
    final anchor = ref.watch(anchorDateProvider);
    // #179：周视图消费「显示周数」偏好（月视图已接，周视图此前恒渲染周数）
    final showWeekNumbers =
        ref.watch(preferenceProvider).value?.showWeekNumbers ?? false;
    final occurrences =
        ref
            .watch(
              occurrencesProvider((
                anchor,
                anchor.add(Duration(days: config.week.numberOfDays)),
              )),
            )
            .value ??
        const [];

    final kalenderConfig = config.week.isWorkWeek
        ? kalender.MultiDayViewConfiguration.workWeek(
            numberOfDays: 5,
            initialDateTime: anchor,
          )
        : kalender.MultiDayViewConfiguration.week(
            numberOfDays: 7,
            initialDateTime: anchor,
          );
    final controller = kalender.KalenderController(
      viewConfiguration: kalenderConfig,
    );

    // #200：装载 CalendarEventTile（带标题/日历色）；#197：延后到帧末（见日视图）
    final loadedEvents = [
      for (final o in occurrences)
          if (o.source == OccurrenceSource.reminder)
            ReminderMarkerEvent(
              id: '${o.eventId}:${o.start.microsecondsSinceEpoch}',
              start: o.start.toUtc(),
              end: o.end.toUtc(),
              isAllDay: o.allDay,
              reminderId: o.reminderId ?? o.eventId,
              colorArgb: o.colorArgb,
              title: o.title,
              completed: o.completed,
            )
          else
          CalendarEventTile(
            id: '${o.eventId}:${o.start.microsecondsSinceEpoch}',
            start: o.start.toUtc(),
            end: o.end.toUtc(),
            isAllDay: o.allDay,
            kernelEventId: o.eventId,
            colorArgb: o.colorArgb,
            title: o.title,
          ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      eventsController.clearEvents();
      eventsController.addEvents(loadedEvents);
    });

    return KeyedSubtree(
      key: const Key('calendar_week_view'),
      child: LifeMaterialIsland(
        child: kalender.KalenderView(
          eventsController: eventsController,
          kalenderController: controller,
          // #193：周视图列头同走 kalender 自己的 locale，必须显式传应用语言
          locale: Localizations.localeOf(context),
          // #179：MultiDay 头部默认恒渲染 WeekNumber；关闭偏好时以空 widget
          // 顶替（kalender 无 showWeekNumbers 字段，只能从 builder 层关）。
          components: kalender.KalenderComponents(
            multiDayComponents: kalender.MultiDayComponents(
              headerComponents: kalender.MultiDayHeaderComponents(
                weekNumberBuilder: showWeekNumbers
                    ? null
                    : (context, range) => const SizedBox.shrink(),
              ),
            ),
          ),
          // #200：显式传 tileComponents（header 全天区 + body 定时区），去默认「Tile」
          views: const [
            kalender.MultiDayViewParts(
              header: _AllDayBand(
                child: kalender.MultiDayHeader(
                  tileComponents: kalender.TileComponents(
                    tileBuilder: dayEventTileBuilder,
                  ),
                ),
              ),
              body: kalender.MultiDayBody(
                tileComponents: kalender.TileComponents(
                  tileBuilder: dayEventTileBuilder,
                ),
              ),
            ),
          ],
          callbacks: kalender.KalenderCallbacks(
            // #225：空区双击创建（Apple：Week 视图双击定时区建日程）。
            onTappedWithDetail: (detail) => handleCalendarTapCreate(
              detail,
              _weekTapTracker,
              onDraftCreate: viewCallbacks.onDraftCreate,
              onDayTap: viewCallbacks.onDayTap,
            ),
            // #240：跨多日横拖要得到覆盖所选日期的多日全天草稿（E2）
            onEventCreate: (event) {
              viewCallbacks.onDragCreate(
                event.start.toLocal(),
                event.end.toLocal(),
              );
              return event;
            },
            onEventChanged: (event, updated) {
              final original = _findOriginal(occurrences, updated.id);
              viewCallbacks.onEventMoved(
                original ?? _toKernel(updated),
                updated.start,
                updated.end,
              );
            },
            onEventTapped: (event) {
              final occurrence = _findOccurrence(occurrences, event.id);
              if (occurrence != null) {
                viewCallbacks.onOccurrenceTapped(occurrence);
              }
            },
            onEventSecondaryTapped: (event) {
              final occurrence = _findOccurrence(occurrences, event.id);
              if (occurrence != null &&
                  occurrence.source == OccurrenceSource.reminder) {
                confirmDeleteReminder(context, viewCallbacks, occurrence);
              }
            },
          ),
        ),
      ),
    );
  }

  CalendarOccurrence? _findOccurrence(
    List<CalendarOccurrence> occurrences,
    String kalenderEventId,
  ) {
    for (final o in occurrences) {
      if (kalenderEventId.startsWith('${o.eventId}:')) {
        return o;
      }
    }
    return null;
  }

  CalendarEvent? _findOriginal(
    List<CalendarOccurrence> occurrences,
    String kalenderEventId,
  ) {
    for (final o in occurrences) {
      if (kalenderEventId.startsWith('${o.eventId}:')) {
        return CalendarEvent(
          id: o.eventId,
          calendarId: o.calendarId,
          uid: o.eventId,
          title: o.title,
          startAt: o.start.toUtc(),
          endAt: o.end.toUtc(),
          allDay: o.allDay,
          timeZone: 'UTC',
          updatedAt: DateTime.now().toUtc(),
        );
      }
    }
    return null;
  }
}

/// kalender 事件 → kernel 事件（拖拽接线翻译兜底）。
CalendarEvent _toKernel(kalender.KalenderEvent event) {
  return CalendarEvent(
    id: event.id,
    calendarId: '',
    uid: '',
    title: '',
    startAt: event.start.toUtc(),
    endAt: event.end.toUtc(),
    timeZone: 'UTC',
    updatedAt: DateTime.now().toUtc(),
  );
}

/// 日视图事件 tile（#184：色=日历颜色，文本=起止时间 + 标题）。
/// Apple 日历：日视图事件条显示标题与起止时间；全天条不带时刻。
Widget dayEventTileBuilder(
  BuildContext context,
  kalender.KalenderEvent event,
  kalender.KalenderDateTimeRange tileRange,
) {
  if (event is ReminderMarkerEvent) {
    return buildReminderMarker(event);
  }
  final tile = event is CalendarEventTile ? event : null;
  final color = Color(tile?.colorArgb ?? 0xFF007AFF);
  final title = tile?.title ?? '';
  final start = event.start.toLocal();
  final end = event.end.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final timeText = event.isAllDay
      ? ''
      : '${two(start.hour)}:${two(start.minute)} – ${two(end.hour)}:${two(end.minute)}';
  return Container(
    key: Key('day-event-${tile?.kernelEventId ?? event.id}'),
    margin: const EdgeInsets.symmetric(horizontal: 1),
    padding: const EdgeInsets.fromLTRB(5, 3, 3, 3),
    decoration: BoxDecoration(
      color: color.withAlpha(60),
      borderRadius: BorderRadius.circular(LifeRadius.xs),
      border: BorderDirectional(start: BorderSide(width: 3, color: color)),
    ),
    alignment: Alignment.topLeft,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (timeText.isNotEmpty)
          Text(
            timeText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: color.withAlpha(200)),
          ),
        if (title.isNotEmpty)
          Flexible(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
      ],
    ),
  );
}
