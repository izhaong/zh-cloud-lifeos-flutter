import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart' as kalender;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../calendar_view_callbacks.dart';
import '../providers.dart';
import 'day_reminder_lane.dart';
import 'month_view.dart' show CalendarEventTile;

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
            child: LifeMaterialIsland(
              child: kalender.KalenderView(
                eventsController: eventsController,
                kalenderController: controller,
                // #193：kalender 默认用自己的 locale（null→intl 默认 en_US），
                // 不传会把中文界面的星期名渲染成 Mon…Sun
                locale: Localizations.localeOf(context),
                // #184：显式传 tileComponents，避免 kalender 默认「Tile」占位文案；
                // header（全天/跨日条）与 body（定时条）都要传——审查 R1 意见
                views: const [
                  kalender.MultiDayViewParts(
                    header: kalender.MultiDayHeader(
                      tileComponents: kalender.TileComponents(
                        tileBuilder: dayEventTileBuilder,
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
                  onEventCreate: (event) {
                    // parity#228：全天区拖多日要得到跨天全天草稿，而不是
                    // 「开始那天 00:00–01:00」的定时草稿。
                    if (CalendarViewCallbacks.looksLikeAllDayRange(
                      event.start.toLocal(),
                      event.end.toLocal(),
                    )) {
                      viewCallbacks.onAllDayDraftCreate(
                        event.start.toLocal(),
                        event.end.toLocal(),
                      );
                    } else {
                      viewCallbacks.onDraftCreate(
                        event.start.toUtc(),
                        event.end.toUtc(),
                      );
                    }
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
          if (showReminderLane) ...[
            Container(width: 1, color: const Color(0xFFC6C6C8)),
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
              header: kalender.MultiDayHeader(
                tileComponents: kalender.TileComponents(
                  tileBuilder: dayEventTileBuilder,
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
            onEventCreate: (event) {
              if (CalendarViewCallbacks.looksLikeAllDayRange(
                event.start.toLocal(),
                event.end.toLocal(),
              )) {
                viewCallbacks.onAllDayDraftCreate(
                  event.start.toLocal(),
                  event.end.toLocal(),
                );
                return event;
              }
              viewCallbacks.onDraftCreate(
                event.start.toUtc(),
                event.end.toUtc(),
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
      borderRadius: BorderRadius.circular(4),
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
