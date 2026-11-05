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
            startAt: DateTime(2026, 10, 26, 9, 30),
            endAt: DateTime(2026, 10, 26, 10, 30),
            timeZone: 'local',
            updatedAt: DateTime.utc(2026, 10, 20),
          ),
          CalendarEvent(
            id: 'e2',
            calendarId: 'c1',
            uid: 'u2',
            title: '评审',
            startAt: DateTime(2026, 10, 27, 14),
            endAt: DateTime(2026, 10, 27, 15),
            timeZone: 'local',
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
      container.read(anchorDateProvider.notifier).set(DateTime(2026, 10, 26));
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
          child: lifeTestHost(CalendarScaffold(pinnedViewMode: mode)),
        ),
      );
      await tester.pumpAndSettle();
    }

    // #553：夹具的「时刻形状」本身就是判据，所以钉成门禁而不是注释。
    // 日/周视图用 `event.start.toLocal()` 落位（`lib/src/views/day_view.dart`），
    // 夹具里只要写 `DateTime.utc(...)`，事件钟点就跟着**执行机器的时区**跑——
    // 同一份基线实测 Asia/Shanghai 差 7.14%、UTC 差 3.57%、America/New_York 近乎为零。
    // 且时间轴只画 dayStartHour–dayEndHour：钟点落在窗外的事件在 golden 里根本不出现，
    // 图照样录得上、事件渲染的覆盖却静默没了。两条都在这里拦住。
    test('golden 夹具：时刻须为本地墙钟且落在时间轴窗口内（#553）', () {
      const pref = CalendarPreference();
      for (final e in repo.events) {
        expect(e.startAt.isUtc, isFalse, reason: '${e.id} startAt 是 UTC 时刻');
        expect(e.endAt.isUtc, isFalse, reason: '${e.id} endAt 是 UTC 时刻');
        expect(
          e.startAt.hour >= pref.dayStartHour &&
              e.endAt.hour <= pref.dayEndHour,
          isTrue,
          reason:
              '${e.id} 落在 ${pref.dayStartHour}–${pref.dayEndHour} 窗外，'
              'golden 拍不到它',
        );
      }
      expect(
        container.read(anchorDateProvider).isUtc,
        isFalse,
        reason: '锚点是 UTC 时刻时会随时区挪一天',
      );
    });
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

    testWidgets('桌面 1280 月视图 暗色（golden 基线；同夹具只改明暗）', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpAt(tester, const Size(1280, 800), CalendarViewMode.month);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop_1280_month_dark.png'),
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
