import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F-07 年视图契约（TC-CAL-UI-104；契约 §5.4）。
void main() {
  late _MutableRepo repo;
  late SharedPreferences prefs;
  final controller = kalenderDefaultController();

  Future<void> pumpYear(WidgetTester tester) async {
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      calendarRepositoryProvider.overrideWithValue(repo),
      sidebarPrefsProvider.overrideWithValue(prefs),
      kalenderEventsControllerProvider.overrideWithValue(controller),
    ]);
    addTearDown(container.dispose);
    container.read(viewModeProvider.notifier).set(CalendarViewMode.year);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: CalendarScaffold()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    controller.clearEvents();
    repo = _MutableRepo();
  });

  // TC-CAL-UI-104：切到年 → 12 个月；今天有红圈；点 11 月进入 11 月月视图
  testWidgets('TC-CAL-UI-104 年视图 12 个月与今天红圈', (tester) async {
    final now = DateTime.now();
    await pumpYear(tester);

    // 12 个迷你月
    expect(find.byKey(const Key('calendar_year_view')), findsOneWidget);
    for (var m = 1; m <= 12; m++) {
      expect(find.byKey(Key('year_month_$m')), findsOneWidget,
          reason: '月卡 $m 存在');
    }
    // 今天红圈（真实当年当月当日）
    expect(find.byKey(Key('year_today_${now.month}_${now.day}')), findsOneWidget,
        reason: '今天红圈');
  });

  testWidgets('TC-CAL-UI-104 点某月切到月视图并设锚点', (tester) async {
    await pumpYear(tester);
    // pumpYear 内部的容器即测试树容器（UncontrolledProviderScope）
    final container = ProviderScope.containerOf(
        tester.element(find.byType(CalendarScaffold)));

    await tester.tap(find.byKey(const Key('year_month_11_tap')));
    await tester.pumpAndSettle();

    final anchor = container.read(anchorDateProvider);
    expect(anchor.month, 11, reason: '锚点切到 11 月');
    expect(container.read(viewModeProvider), CalendarViewMode.month,
        reason: '进入月视图');
    expect(find.byKey(const Key('calendar_month_view')), findsOneWidget);
  });

  testWidgets('有事件的日期下画小圆点（最多 3 色）', (tester) async {
    await repo.upsertEvent(CalendarEvent(
      id: 'e1',
      calendarId: 'c1',
      uid: 'u1',
      title: '事件甲',
      startAt: DateTime.utc(2026, 6, 15, 10),
      endAt: DateTime.utc(2026, 6, 15, 11),
      timeZone: 'UTC',
      updatedAt: DateTime.utc(2026, 6, 1),
    ));
    await pumpYear(tester);
    // 默认日历色回退 0xFF007AFF；月 6 日 15 有该色圆点
    expect(
        find.byKey(const Key('year_dot_6_15_ff007aff')), findsOneWidget,
        reason: '事件日圆点用日历颜色');
  });
}

kalender.DefaultEventsController kalenderDefaultController() =>
    kalender.DefaultEventsController();

/// 可变假仓库（F-07）。
class _MutableRepo implements CalendarRepository {
  final List<CalendarEvent> visible = [];
  final _eventController = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<CalendarEvent>> watchEvents(
      {required DateTime from, required DateTime to, Set<String>? calendarIds}) async* {
    yield List<CalendarEvent>.unmodifiable(visible);
    yield* _eventController.stream;
  }

  @override
  Future<String> upsertEvent(CalendarEvent e,
      {EditScope scope = EditScope.all, DateTime? occurrenceStart}) async {
    visible.add(e);
    _eventController.add(List<CalendarEvent>.unmodifiable(visible));
    return e.id;
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
    yield* const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
