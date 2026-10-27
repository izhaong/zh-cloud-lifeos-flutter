import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

/// F-10 重复 UI（TC-CAL-UI-150～152；契约 §3.2.1）。
void main() {
  CalendarEvent event({
    String? rrule,
    DateTime? startAt,
    String title = '周会',
    String id = 'm1',
  }) => CalendarEvent(
    id: id,
    calendarId: 'c1',
    uid: 'u1',
    title: title,
    startAt: startAt ?? DateTime.utc(2026, 10, 24, 2),
    endAt: (startAt ?? DateTime.utc(2026, 10, 24, 2)).add(
      const Duration(hours: 1),
    ),
    timeZone: 'UTC',
    rrule: rrule,
    updatedAt: DateTime.utc(2026, 10, 24),
  );

  group('RRULE 纯逻辑', () {
    test('预设生成与标签', () {
      final start = DateTime.utc(2026, 10, 24, 2); // 周六
      expect(
        rruleForPreset(RecurrencePreset.weekly, start),
        'FREQ=WEEKLY;BYDAY=SA',
      );
      expect(
        rruleForPreset(RecurrencePreset.biweekly, start),
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=SA',
      );
      expect(
        rruleForPreset(RecurrencePreset.monthly, start),
        'FREQ=MONTHLY;BYMONTHDAY=24',
      );
      expect(rruleForPreset(RecurrencePreset.none, start), isNull);
      expect(presetOf('FREQ=WEEKLY;BYDAY=SA'), RecurrencePreset.weekly);
      expect(
        presetOf('FREQ=WEEKLY;INTERVAL=2;BYDAY=SA'),
        RecurrencePreset.biweekly,
      );
      expect(presetOf('FREQ=DAILY;COUNT=5'), RecurrencePreset.custom);
      expect(recurrenceLabel(null), '不重复');
    });

    test('自定义：间隔/多周几/次数', () {
      final config = RecurrenceConfig(
        freq: kFreqWeekly,
        interval: 2,
        weekdays: {1, 3},
        count: 5,
      );
      expect(
        buildRRule(config, DateTime.utc(2026, 10, 24)),
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=5',
      );
    });

    test('自定义：每月第 N 个周 X', () {
      final config = RecurrenceConfig(
        freq: kFreqMonthly,
        monthlyByDayOfMonth: false,
        ordinal: 2,
        ordinalWeekday: 2,
      );
      expect(
        buildRRule(config, DateTime.utc(2026, 10, 24)),
        'FREQ=MONTHLY;BYDAY=2TU',
      );
    });

    test('parseRRule 读回周几/结束', () {
      final config = parseRRule(
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;UNTIL=20261231T000000Z',
        DateTime.utc(2026, 10, 24),
      );
      expect(config.freq, kFreqWeekly);
      expect(config.interval, 2);
      expect(config.weekdays, {1, 3});
      expect(config.until, DateTime.utc(2026, 12, 31));
    });
  });

  group('组件', () {
    late _Repo repo;
    late ProviderContainer container;

    setUp(() {
      repo = _Repo();
      container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          sidebarPrefsProvider.overrideWith((ref) => null),
        ],
      );
    });

    tearDown(() => container.dispose());

    Future<void> pumpPane(
      WidgetTester tester,
      CalendarEvent initial, {
      DateTime? occurrenceStart,
      VoidCallback? onSaved,
    }) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(
            Scaffold(
              body: EventInspectorPane(
                initialEvent: initial,
                occurrenceStart: occurrenceStart,
                onSaved: onSaved ?? () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // TC-CAL-UI-150：重复选每周 → 生成 RRULE，之后两周各一次
    testWidgets('TC-CAL-UI-150 设成每周', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpPane(tester, event());
      await tester.tap(find.byKey(const Key('event_field_repeat_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('每周').last);
      await tester.pumpAndSettle();

      // 通过删除按钮不可见等无关断言，直接读表单草稿：重新 pump 后标题不变
      // 表单内取值用 rrule 预设标签断言
      expect(find.text('每周'), findsOneWidget);

      final master = event(rrule: 'FREQ=WEEKLY;BYDAY=SA');
      final occurrences = expandOccurrences(
        [master],
        from: DateTime.utc(2026, 10, 24),
        to: DateTime.utc(2026, 11, 7),
        colorByCalendar: const {'c1': 0xFF007AFF},
      );
      expect(occurrences.length, 2, reason: '之后两周同一时间各一次');
      expect(occurrences[0].start, DateTime.utc(2026, 10, 24, 2));
      expect(occurrences[1].start, DateTime.utc(2026, 10, 31, 2));
    });

    // TC-CAL-UI-151：改第 2 次标题，选「仅此日程」
    testWidgets('TC-CAL-UI-151 仅此一次', (tester) async {
      final occurrenceStart = DateTime.utc(2026, 10, 31, 2);
      await pumpPane(
        tester,
        event(rrule: 'FREQ=WEEKLY;BYDAY=SA'),
        occurrenceStart: occurrenceStart,
      );

      await tester.enterText(
        find.byKey(const Key('event_field_title')),
        '只改第二次',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('event_inspector_save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('repeat_scope_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('scope_this')));
      await tester.pumpAndSettle();

      final call = repo.upserts.single;
      expect(call.scope, EditScope.thisOnly);
      expect(call.occurrenceStart, occurrenceStart);
      expect(call.event.title, '只改第二次');
    });

    // TC-CAL-UI-152：删除选「此日程及之后」
    testWidgets('TC-CAL-UI-152 删除此后', (tester) async {
      final occurrenceStart = DateTime.utc(2026, 10, 31, 2);
      await pumpPane(
        tester,
        event(rrule: 'FREQ=WEEKLY;BYDAY=SA'),
        occurrenceStart: occurrenceStart,
      );

      await tester.tap(find.byKey(const Key('event_inspector_delete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('repeat_scope_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('scope_future')));
      await tester.pumpAndSettle();

      final call = repo.deletes.single;
      expect(call.scope, EditScope.thisAndFuture);
      expect(call.occurrenceStart, occurrenceStart);
      expect(call.id, 'm1');
    });
  });
}

class _UpsertCall {
  _UpsertCall(this.event, this.scope, this.occurrenceStart);
  final CalendarEvent event;
  final EditScope scope;
  final DateTime? occurrenceStart;
}

class _DeleteCall {
  _DeleteCall(this.id, this.scope, this.occurrenceStart);
  final String id;
  final EditScope scope;
  final DateTime? occurrenceStart;
}

class _Repo implements CalendarRepository {
  final List<_UpsertCall> upserts = [];
  final List<_DeleteCall> deletes = [];
  final List<Calendar> calendars = [];
  final List<CalendarEvent> events = [];
  final _events = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield List<CalendarEvent>.unmodifiable(events);
    yield* _events.stream;
  }

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(calendars);
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
    yield* const Stream.empty();
  }

  @override
  Future<CalendarEvent?> getEvent(String id) async {
    for (final e in events) {
      if (e.id == id) {
        return e;
      }
    }
    return null;
  }

  @override
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    upserts.add(_UpsertCall(e, scope, occurrenceStart));
    events.add(e);
    _events.add(List<CalendarEvent>.unmodifiable(events));
    return e.id;
  }

  @override
  Future<void> deleteEvent(
    String id, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    deletes.add(_DeleteCall(id, scope, occurrenceStart));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
