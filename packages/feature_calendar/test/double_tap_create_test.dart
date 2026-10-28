import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

/// #225 双击创建（矩阵 D3/D4/E1；TC-CAL-UI-130/131）。
///
/// kalender 0.33.0 没有双击识别器，只有 `onTappedWithDetail`
/// （`DayDetail` 定时区 / `MultiDayDetail` 全天区与月格）。这里钉住：
/// - 单击不创建（Apple：日/周空区单击无动作）
/// - 两次快速点按 → 一次草稿（不是两次）
/// - 日视图落点时刻 = 点按位置换算（含吸附），时长取偏好默认
/// - 月视图落点日期 = 点按格子，默认全天
void main() {
  late _Repo repo;
  late List<CalendarEvent> drafts;
  final controller = kalender.DefaultEventsController();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    repo = _Repo();
    drafts = [];
    controller.clearEvents();
  });

  CalendarViewCallbacks callbacks() => CalendarViewCallbacks(
        repo: repo,
        preference: const CalendarPreference(),
        timeZone: 'UTC',
        setDraft: drafts.add,
      );

  Future<void> pumpDay(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          kalenderEventsControllerProvider.overrideWithValue(controller),
        ],
        child: lifeTestHost(
          Scaffold(
            body: CalendarDayView(
              viewCallbacks: callbacks(),
              eventsController: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpWeek(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          kalenderEventsControllerProvider.overrideWithValue(controller),
        ],
        child: lifeTestHost(
          Scaffold(
            body: CalendarWeekView(
              viewCallbacks: callbacks(),
              eventsController: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpMonth(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          kalenderEventsControllerProvider.overrideWithValue(controller),
        ],
        child: lifeTestHost(
          Scaffold(
            body: CalendarMonthView(
              viewCallbacks: callbacks(),
              eventsController: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CalendarDoubleTapTracker', () {
    test('窗口内同日同区两次点按 = 双击', () {
      final t = CalendarDoubleTapTracker();
      final day = DateTime(2026, 10, 28);
      final at = DateTime(2026, 10, 28, 10);
      expect(t.register(day: day, now: at), isFalse);
      expect(
        t.register(day: day, now: at.add(const Duration(milliseconds: 150))),
        isTrue,
      );
    });

    test('超出窗口不算双击', () {
      final t = CalendarDoubleTapTracker();
      final day = DateTime(2026, 10, 28);
      final at = DateTime(2026, 10, 28, 10);
      t.register(day: day, now: at);
      expect(
        t.register(day: day, now: at.add(const Duration(milliseconds: 600))),
        isFalse,
      );
    });

    test('不同日期 / 定时与全天区不串味', () {
      final t = CalendarDoubleTapTracker();
      final at = DateTime(2026, 10, 28, 10);
      t.register(day: DateTime(2026, 10, 28), now: at);
      expect(
        t.register(day: DateTime(2026, 10, 29), now: at),
        isFalse,
        reason: '跨日不算双击',
      );

      final t2 = CalendarDoubleTapTracker();
      t2.register(day: DateTime(2026, 10, 28), now: at);
      expect(
        t2.register(day: DateTime(2026, 10, 28), allDay: true, now: at),
        isFalse,
        reason: '定时区与全天区各自成对',
      );
    });

    test('三连击只产生一次创建', () {
      final t = CalendarDoubleTapTracker();
      final day = DateTime(2026, 10, 28);
      final at = DateTime(2026, 10, 28, 10);
      t.register(day: day, now: at);
      expect(t.register(day: day, now: at), isTrue);
      expect(
        t.register(day: day, now: at),
        isFalse,
        reason: '命中后节拍清零，第三下重新计数',
      );
    });
  });

  group('CalendarTapGate（月视图一次创建闸门）', () {
    test('第一下放行、紧随的第二下吞掉', () {
      final g = CalendarTapGate();
      final day = DateTime(2026, 10, 28);
      final at = DateTime(2026, 10, 28, 10);
      expect(g.allow(day, now: at), isTrue);
      expect(
        g.allow(day, now: at.add(const Duration(milliseconds: 150))),
        isFalse,
        reason: '双击的第二下不能再建一份草稿',
      );
    });

    test('超过窗口的第二下照常放行（两次独立单击）', () {
      final g = CalendarTapGate();
      final day = DateTime(2026, 10, 28);
      final at = DateTime(2026, 10, 28, 10);
      expect(g.allow(day, now: at), isTrue);
      expect(
        g.allow(day, now: at.add(const Duration(milliseconds: 600))),
        isTrue,
      );
    });

    test('不同日期的快速两下都放行', () {
      final g = CalendarTapGate();
      final at = DateTime(2026, 10, 28, 10);
      expect(g.allow(DateTime(2026, 10, 28), now: at), isTrue);
      expect(g.allow(DateTime(2026, 10, 29), now: at), isTrue);
    });
  });

  group('TC-CAL-UI-130 日视图双击创建', () {
    testWidgets('单击时间轴空白不创建草稿', (tester) async {
      await pumpDay(tester);
      final rect = tester.getRect(find.byType(kalender.MultiDayBody));
      await tester.tapAt(
        Offset(rect.center.dx, rect.top + rect.height * 0.2),
      );
      await tester.pumpAndSettle();
      expect(drafts, isEmpty, reason: 'Apple：日视图单击空区无动作');
    });

    testWidgets('双击 10:00 处 → 草稿开始于 10:00、时长=偏好默认', (tester) async {
      await pumpDay(tester);
      final rect = tester.getRect(find.byType(kalender.MultiDayBody));
      // dayStartHour=8 / dayEndHour=18 → 0.2 高度处即 10:00。
      final point = Offset(rect.center.dx, rect.top + rect.height * 0.2);

      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(point);
      await tester.pumpAndSettle();

      expect(drafts, hasLength(1), reason: '双击只产生一次草稿');
      final draft = drafts.single;
      final today = DateTime.now();
      expect(
        draft.startAt.toLocal(),
        DateTime(today.year, today.month, today.day, 10),
        reason: '草稿起点=双击位置换算的当地时刻（dayStartHour=8，0.2 高度即 10:00）',
      );
      expect(
        draft.endAt.difference(draft.startAt),
        const Duration(minutes: 60),
        reason: '时长取 preference.defaultDurationMinutes',
      );
      expect(draft.allDay, isFalse);
    });
  });

  group('D3 周视图双击创建', () {
    testWidgets('双击周视图时间轴 10:00 处 → 草稿', (tester) async {
      await pumpWeek(tester);
      final rect = tester.getRect(find.byType(kalender.MultiDayBody));
      final point = Offset(rect.left + rect.width / 4, rect.top + rect.height * 0.2);

      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(point);
      await tester.pumpAndSettle();

      expect(drafts, hasLength(1));
      expect(drafts.single.allDay, isFalse);
      expect(
        drafts.single.endAt.difference(drafts.single.startAt),
        const Duration(minutes: 60),
      );
    });
  });

  group('TC-CAL-UI-131 月视图双击创建（默认全天）', () {
    testWidgets('双击 15 号格子空白 → 该日全天草稿，且只创建一次', (tester) async {
      await pumpMonth(tester);
      final anchor = DateTime.now();
      final header = find.text('15');
      expect(header, findsWidgets, reason: '月网格应渲染 15 号日期头');
      final cell = tester.getRect(header.first);
      // 日期头下方仍是同一格子（事件区/空白区）。
      final point = Offset(cell.center.dx, cell.bottom + 60);

      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(point);
      await tester.pumpAndSettle();

      expect(
        drafts,
        hasLength(1),
        reason: '双击只落一次草稿：第二下必须被闸门吞掉，否则会点到草稿弹层遮罩把草稿关掉',
      );
      final draft = drafts.single;
      expect(draft.allDay, isTrue, reason: '月格双击默认全天');
      final start = wallTimeOf(draft.startAt, 'UTC');
      expect(
        DateTime(start.year, start.month, start.day),
        DateTime(anchor.year, anchor.month, 15),
        reason: '草稿落在被双击的格子日期',
      );
    });

    testWidgets('单击格子空白仍按既有口径创建一次（TC-CAL-UI-131）', (tester) async {
      await pumpMonth(tester);
      final header = find.text('15');
      final cell = tester.getRect(header.first);
      await tester.tapAt(Offset(cell.center.dx, cell.bottom + 60));
      await tester.pumpAndSettle();
      expect(drafts, hasLength(1), reason: '单击创建是既有行为，本卡不回归');
    });

  });
}

/// 只读替身：本卡只验证草稿创建，不落库。
class _Repo implements CalendarRepository {
  final _calendars = StreamController<List<Calendar>>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield const <Calendar>[];
    yield* _calendars.stream;
  }

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield const <CalendarEvent>[];
  }

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(const CalendarPreference());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
