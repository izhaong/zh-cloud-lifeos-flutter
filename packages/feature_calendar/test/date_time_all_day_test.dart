import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// F-09 日期时间 / 全天 / 时区（TC-CAL-KR-120、TC-CAL-UI-140；契约 §2.2）。
void main() {
  CalendarEvent event({
    bool allDay = false,
    String timeZone = 'Asia/Shanghai',
    DateTime? startAt,
    DateTime? endAt,
  }) =>
      CalendarEvent(
        id: 'e1',
        calendarId: 'c1',
        uid: 'u1',
        title: '周会',
        startAt: startAt ?? DateTime.utc(2026, 10, 24, 2),
        endAt: endAt ?? DateTime.utc(2026, 10, 24, 3),
        allDay: allDay,
        timeZone: timeZone,
        updatedAt: DateTime.utc(2026, 10, 24),
      );

  // TC-CAL-KR-120：全天按 event.timeZone 归一到当地 00:00 → 次日 00:00（UTC 存储）
  test('TC-CAL-KR-120 全天归一（上海）', () {
    final normalized = normalizeAllDay(event());

    expect(normalized.allDay, isTrue);
    // 2026-10-24 00:00 +08:00
    expect(normalized.startAt, DateTime.utc(2026, 10, 23, 16));
    // 2026-10-25 00:00 +08:00（排他）
    expect(normalized.endAt, DateTime.utc(2026, 10, 24, 16));
  });

  // TC-CAL-KR-120：跨夏令时的一天是 23 小时（纽约 2026-03-08 春令时）
  test('TC-CAL-KR-120 全天归一跨夏令时（纽约 23h）', () {
    final normalized = normalizeAllDay(event(
      timeZone: 'America/New_York',
      startAt: DateTime.utc(2026, 3, 8, 12),
      endAt: DateTime.utc(2026, 3, 8, 13),
    ));

    // 2026-03-08 00:00 EST = 05:00Z；2026-03-09 00:00 EDT = 04:00Z
    expect(normalized.startAt, DateTime.utc(2026, 3, 8, 5));
    expect(normalized.endAt, DateTime.utc(2026, 3, 9, 4));
    expect(normalized.endAt.difference(normalized.startAt),
        const Duration(hours: 23));
  });

  // TC-CAL-KR-120：换时区保持墙上时间（Apple 语义）
  test('TC-CAL-KR-120 换时区保持墙上时间', () {
    final moved = setTimeZone(event(), 'UTC');

    // 上海 10:00 → UTC 10:00
    expect(moved.timeZone, 'UTC');
    expect(moved.startAt, DateTime.utc(2026, 10, 24, 10));
    expect(moved.endAt, DateTime.utc(2026, 10, 24, 11));
  });

  group('TC-CAL-UI-140 表单', () {
    late _Repo repo;
    late ProviderContainer container;

    setUp(() {
      repo = _Repo();
      container = ProviderContainer(overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
      ]);
    });

    tearDown(() => container.dispose());

    Future<_HarnessState> pumpForm(
      WidgetTester tester,
      CalendarEvent initial,
    ) async {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: _Harness(initial: initial)),
        ),
      ));
      await tester.pumpAndSettle();
      return tester.state<_HarnessState>(find.byType(_Harness));
    }

    testWidgets('全天隐藏时刻，切全天按契约归一', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = await pumpForm(tester, event());
      expect(find.text('2026-10-24 10:00'), findsOneWidget,
          reason: '定时事件显示墙上时刻');

      await tester.tap(find.byKey(const Key('event_field_all_day')));
      await tester.pumpAndSettle();

      expect(state.event.allDay, isTrue);
      expect(state.event.startAt, DateTime.utc(2026, 10, 23, 16));
      expect(find.text('2026-10-24'), findsWidgets, reason: '全天只显示日期');
      expect(find.textContaining('2026-10-24 10:00'), findsNothing,
          reason: '全天隐藏时刻');
    });

    testWidgets('浮动时间开关仅在偏好 timeZoneSupport=true 时出现', (tester) async {
      await pumpForm(tester, event());
      expect(find.byKey(const Key('event_field_floating')), findsNothing,
          reason: '默认偏好不显示');

      container.dispose();
      repo = _Repo(pref: const CalendarPreference(timeZoneSupport: true));
      container = ProviderContainer(overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
      ]);
      await pumpForm(tester, event());
      expect(find.byKey(const Key('event_field_floating')), findsOneWidget,
          reason: '偏好开启后显示');
    });

    testWidgets('时区对话框搜索并选择，保持墙上时间', (tester) async {
      final state = await pumpForm(tester, event());
      await tester.tap(find.byKey(const Key('event_field_timezone')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('event_timezone_dialog')), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('event_timezone_search')), 'UTC');
      await tester.pump();
      await tester.tap(find.byKey(const Key('event_timezone_option_UTC')));
      await tester.pumpAndSettle();

      expect(state.event.timeZone, 'UTC');
      expect(state.event.startAt, DateTime.utc(2026, 10, 24, 10),
          reason: '墙上 10:00 不变');
      expect(find.byKey(const Key('event_timezone_dialog')), findsNothing);
    });
  });

  // TC-CAL-KR-120：Inspector 保存前再兜底归一（不依赖开关路径）
  testWidgets('Inspector 保存全天事件前归一', (tester) async {
    final repo = _Repo();
    final container = ProviderContainer(overrides: [
      calendarRepositoryProvider.overrideWithValue(repo),
      sidebarPrefsProvider.overrideWith((ref) => null),
    ]);
    addTearDown(container.dispose);
    repo.calendars.add(const Calendar(
        id: 'c1', title: '工作', colorArgb: 0xFF007AFF));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: EventInspectorPane(
            initialEvent: event(allDay: true),
            onSaved: () {},
            onClose: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('event_inspector_save')));
    await tester.pumpAndSettle();

    final saved = repo.upserted.single;
    expect(saved.startAt, DateTime.utc(2026, 10, 23, 16));
    expect(saved.endAt, DateTime.utc(2026, 10, 24, 16));
  });
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

class _Repo implements CalendarRepository {
  _Repo({this.pref = const CalendarPreference()});

  final CalendarPreference pref;
  final List<Calendar> calendars = [];
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
    yield List<Calendar>.unmodifiable(calendars);
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield pref;
    yield* const Stream.empty();
  }

  @override
  Future<String> upsertEvent(CalendarEvent e,
      {EditScope scope = EditScope.all, DateTime? occurrenceStart}) async {
    upserted.add(e);
    return e.id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
