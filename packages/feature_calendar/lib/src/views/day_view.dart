import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart' as kalender;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../calendar_view_callbacks.dart';
import '../providers.dart';
import 'day_reminder_lane.dart';

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
  });

  final CalendarViewCallbacks viewCallbacks;
  final kalender.DefaultEventsController eventsController;

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
    eventsController.clearEvents();
    eventsController.addEvents([
      for (final o in occurrences)
        if (o.source != OccurrenceSource.holiday)
          kalender.KalenderEvent(
            id: '${o.eventId}:${o.start.microsecondsSinceEpoch}',
            start: o.start.toUtc(),
            end: o.end.toUtc(),
            isAllDay: o.allDay,
          ),
    ]);

    final controller = kalender.KalenderController(
      viewConfiguration: kalender.MultiDayViewConfiguration.singleDay(
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
                views: const [kalender.MultiDayViewParts()],
                callbacks: kalender.KalenderCallbacks(
                  onEventCreate: (event) {
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
          Container(width: 1, color: const Color(0xFFC6C6C8)),
          const SizedBox(width: 220, child: DayReminderLane()),
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
        ? kalender.MultiDayViewConfiguration.workWeek(numberOfDays: 5)
        : kalender.MultiDayViewConfiguration.week(numberOfDays: 7);
    final controller = kalender.KalenderController(
      viewConfiguration: kalenderConfig,
    );

    eventsController.clearEvents();
    eventsController.addEvents([
      for (final o in occurrences)
        if (o.source != OccurrenceSource.holiday)
          kalender.KalenderEvent(
            id: '${o.eventId}:${o.start.microsecondsSinceEpoch}',
            start: o.start.toUtc(),
            end: o.end.toUtc(),
            isAllDay: o.allDay,
          ),
    ]);

    return KeyedSubtree(
      key: const Key('calendar_week_view'),
      child: LifeMaterialIsland(
        child: kalender.KalenderView(
          eventsController: eventsController,
          kalenderController: controller,
          views: const [kalender.MultiDayViewParts()],
          callbacks: kalender.KalenderCallbacks(
            onEventCreate: (event) {
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
