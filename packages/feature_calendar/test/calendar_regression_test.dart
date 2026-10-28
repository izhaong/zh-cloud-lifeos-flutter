import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'support/life_test_app.dart';

/// R-01 回归：负向可执行项 + 性能（TC-CAL-REG-005）。
void main() {
  test('TC-CAL-REG-005 万级 occurrence 展开单次 < 200ms', () {
    final master = CalendarEvent(
      id: 'm1',
      calendarId: 'c1',
      uid: 'u1',
      title: '每日站会',
      startAt: DateTime.utc(2026, 1, 1, 2),
      endAt: DateTime.utc(2026, 1, 1, 2, 30),
      timeZone: 'UTC',
      rrule: 'FREQ=DAILY',
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final from = DateTime.utc(2026, 1, 1);
    final to = DateTime.utc(2026, 3, 4); // 62 天
    final sw = Stopwatch()..start();
    for (var i = 0; i < 200; i++) {
      final result = expandOccurrences(
        [master],
        from: from,
        to: to,
        colorByCalendar: const {'c1': 0xFF007AFF},
      );
      expect(result.length, 62);
    }
    sw.stop();
    final perRunMs = sw.elapsedMicroseconds / 200 / 1000;
    expect(
      perRunMs,
      lessThan(200),
      reason: '单次 ${perRunMs.toStringAsFixed(2)}ms',
    );
  });

  group('三档断点（R-01 golden）', () {
    final repo = _Repo();
    late ProviderContainer container;
    final controller = kalender.DefaultEventsController();

    setUp(() {
      repo.calendars
        ..clear()
        ..add(
          const Calendar(
            id: 'c1',
            title: '工作',
            colorArgb: 0xFF007AFF,
            isDefault: true,
          ),
        );
      repo.events
        ..clear()
        ..addAll([
          CalendarEvent(
            id: 'e1',
            calendarId: 'c1',
            uid: 'u1',
            title: '周会',
            startAt: DateTime.utc(2026, 10, 26, 2),
            endAt: DateTime.utc(2026, 10, 26, 3),
            timeZone: 'UTC',
            updatedAt: DateTime.utc(2026, 10, 20),
          ),
          CalendarEvent(
            id: 'e2',
            calendarId: 'c1',
            uid: 'u2',
            title: '评审',
            startAt: DateTime.utc(2026, 10, 27, 6),
            endAt: DateTime.utc(2026, 10, 27, 7),
            timeZone: 'UTC',
            updatedAt: DateTime.utc(2026, 10, 20),
          ),
        ]);
      container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          sidebarPrefsProvider.overrideWith((ref) => null),
          kalenderEventsControllerProvider.overrideWithValue(controller),
          // #331：钉死挂钟——月/年视图的「今天」高亮直接取它，golden 才能确定化。
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 26)),
        ],
      );
      container
          .read(anchorDateProvider.notifier)
          .set(DateTime.utc(2026, 10, 26));
    });

    tearDown(() => container.dispose());

    Future<void> pumpAt(
      WidgetTester tester,
      Size size,
      CalendarViewMode mode,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(CalendarScaffold(initialViewMode: mode)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('iPhone 375 日视图（golden 基线；挂钟已注入固定 2026-10-26，确定性）', (
      tester,
    ) async {
      await pumpAt(tester, const Size(375, 812), CalendarViewMode.day);
      expect(find.byKey(const Key('calendar_toolbar')), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/iphone_375_day.png'),
      );
    });

    testWidgets('iPad 834 周视图（golden 基线；挂钟已注入固定 2026-10-26，确定性）', (
      tester,
    ) async {
      await pumpAt(tester, const Size(834, 1112), CalendarViewMode.week);
      expect(find.byKey(const Key('calendar_week_view')), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/ipad_834_week.png'),
      );
    });

    testWidgets('桌面 1280 月视图 + 侧栏（golden 基线；挂钟已注入固定 2026-10-26，确定性）', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1280, 800), CalendarViewMode.month);
      expect(find.byKey(const Key('calendar_sidebar')), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop_1280_month.png'),
      );
    });
  });
}

class _Repo implements CalendarRepository {
  final List<Calendar> calendars = [];
  final List<CalendarEvent> events = [];
  final _c = StreamController<List<Calendar>>.broadcast();
  final _e = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(calendars);
    yield* _c.stream;
  }

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield List<CalendarEvent>.unmodifiable(events);
    yield* _e.stream;
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
    yield* const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
