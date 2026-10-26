import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// F-11 提醒与本地通知（TC-CAL-UI-153～155；契约 §2.3）。
void main() {
  CalendarEvent event({bool allDay = false}) => CalendarEvent(
        id: 'e1',
        calendarId: 'c1',
        uid: 'u1',
        title: '周会',
        startAt: DateTime.utc(2026, 10, 24, 2),
        endAt: DateTime.utc(2026, 10, 24, 3),
        allDay: allDay,
        timeZone: 'Asia/Shanghai',
        updatedAt: DateTime.utc(2026, 10, 24),
      );

  group('触发时刻', () {
    test('定时：偏移按分钟加减并过滤过去', () {
      final e = event();
      final withAlerts = calendarEventWithAlerts(e, const [
        EventAlert(offsetMinutes: -15),
        EventAlert(offsetMinutes: 0),
      ]);
      expect(calendarAlertTriggers(withAlerts), [
        DateTime.utc(2026, 10, 24, 1, 45),
        DateTime.utc(2026, 10, 24, 2),
      ]);
      expect(
          calendarAlertTriggers(withAlerts,
              after: DateTime.utc(2026, 10, 24, 1, 50)),
          [DateTime.utc(2026, 10, 24, 2)]);
    });

    test('全天：提前天数 + 当地时刻（上海 09:00）', () {
      // 全天事件 2026-10-24 当地 00:00 = 2026-10-23T16:00Z
      final e = event(allDay: true);
      final withAlerts = calendarEventWithAlerts(e, const [
        EventAlert(allDayOffsetDays: 1, allDayTime: '09:00'),
        EventAlert(allDayOffsetDays: 0, allDayTime: '09:00'),
      ]);
      expect(calendarAlertTriggers(withAlerts), [
        DateTime.utc(2026, 10, 23, 1), // 10-23 09:00 +08
        DateTime.utc(2026, 10, 24, 1), // 10-24 09:00 +08
      ]);
    });
  });

  group('表单与通知动作', () {
    testWidgets('TC-CAL-UI-153/155 多选提醒写入 EventAlert', (tester) async {
      final container = ProviderContainer(overrides: [
        calendarRepositoryProvider.overrideWithValue(_Repo()),
        sidebarPrefsProvider.overrideWith((ref) => null),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: _Harness(initial: event())),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('event_field_alerts')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('alert_timed_-15')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('alerts_dialog_save')));
      await tester.pumpAndSettle();

      final state = tester.state<_HarnessState>(find.byType(_Harness));
      expect(state.event.alerts.single.offsetMinutes, -15,
          reason: 'TC-CAL-UI-153');

      // TC-CAL-UI-155：再加「当时」→ 两条
      await tester.tap(find.byKey(const Key('event_field_alerts')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('alert_timed_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('alerts_dialog_save')));
      await tester.pumpAndSettle();

      expect(state.event.alerts.length, 2, reason: 'TC-CAL-UI-155');
      expect(state.event.alerts.map((a) => a.offsetMinutes), [0, -15],
          reason: '按契约预设顺序（0 在 -15 之前）');
    });

    testWidgets('TC-CAL-UI-154 稍后提醒 = 9 分钟后', (tester) async {
      final fake = _FakeScheduler();
      final now = DateTime.utc(2026, 10, 24, 2);
      final actions =
          CalendarNotificationActions(fake, clock: () => now);

      await actions.onSnooze(event());
      await actions.onDismiss('e1');

      expect(fake.snoozed.single,
          now.add(const Duration(minutes: 9)),
          reason: '9 分钟后的新触发');
      expect(fake.cancelled, ['e1']);
    });

    testWidgets('保存后调度、删除后取消（Noop 之外的真实调用点）', (tester) async {
      final fake = _FakeScheduler();
      final repo = _Repo();
      final container = ProviderContainer(overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
        calendarAlertSchedulerProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EventInspectorPane(
              initialEvent: event(),
              onSaved: () {},
              onClose: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event_inspector_save')));
      await tester.pumpAndSettle();
      expect(fake.scheduled.single, 'e1');

      await tester.tap(find.byKey(const Key('event_inspector_delete')));
      await tester.pumpAndSettle();
      expect(fake.cancelled, ['e1']);
    });
  });
}

CalendarEvent calendarEventWithAlerts(
    CalendarEvent e, List<EventAlert> alerts) {
  return CalendarEvent(
    id: e.id,
    remoteId: e.remoteId,
    calendarId: e.calendarId,
    uid: e.uid,
    title: e.title,
    location: e.location,
    url: e.url,
    notes: e.notes,
    startAt: e.startAt,
    endAt: e.endAt,
    allDay: e.allDay,
    timeZone: e.timeZone,
    isFloating: e.isFloating,
    rrule: e.rrule,
    exdates: e.exdates,
    parentEventId: e.parentEventId,
    originalStartAt: e.originalStartAt,
    status: e.status,
    availability: e.availability,
    travelMinutes: e.travelMinutes,
    isPrivate: e.isPrivate,
    alerts: alerts,
    invitees: e.invitees,
    sequence: e.sequence,
    revision: e.revision,
    deletedAt: e.deletedAt,
    updatedAt: e.updatedAt,
  );
}

class _Harness extends StatefulWidget {
  const _Harness({required this.initial});

  final CalendarEvent initial;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late CalendarEvent event = widget.initial;

  @override
  Widget build(BuildContext context) {
    return EventFormFields(
      event: event,
      onChanged: (next) => setState(() => event = next),
    );
  }
}

class _FakeScheduler implements CalendarAlertScheduler {
  final List<String> scheduled = [];
  final List<String> cancelled = [];
  final List<DateTime> snoozed = [];

  @override
  Future<void> scheduleEvent(CalendarEvent event) async {
    scheduled.add(event.id);
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    cancelled.add(eventId);
  }

  @override
  Future<void> snooze(CalendarEvent event, DateTime fireAt) async {
    snoozed.add(fireAt);
  }
}

class _Repo implements CalendarRepository {
  final List<CalendarEvent> upserted = [];
  final _events = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<CalendarEvent>> watchEvents(
          {required DateTime from,
          required DateTime to,
          Set<String>? calendarIds}) async* {
    yield const <CalendarEvent>[];
    yield* _events.stream;
  }

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield const <Calendar>[];
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
    yield* const Stream.empty();
  }

  @override
  Future<String> upsertEvent(CalendarEvent e,
      {EditScope scope = EditScope.all, DateTime? occurrenceStart}) async {
    upserted.add(e);
    return e.id;
  }

  @override
  Future<void> deleteEvent(String id,
      {EditScope scope = EditScope.all, DateTime? occurrenceStart}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
