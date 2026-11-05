// TC-CAL-UI-1xx / 矩阵 I17（#399）：第 5 个视图档「列表」必须是真的列表，
// 不是一行占位 `Text('列表')`。
import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/life_test_app.dart';

class _Repo implements CalendarRepository {
  _Repo({required this.events});

  final List<CalendarEvent> events;
  final List<Calendar> calendars = const [
    Calendar(id: 'c1', title: '工作', colorArgb: 0xFF007AFF),
  ];

  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(calendars);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) =>
      Stream.value(events
          .where((e) => !e.startAt.isBefore(from) && e.startAt.isBefore(to))
          .toList());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CalendarEvent _event(String id, String title, DateTime start,
        {bool allDay = false}) =>
    CalendarEvent(
      id: id,
      calendarId: 'c1',
      uid: id,
      title: title,
      startAt: start,
      endAt: start.add(const Duration(hours: 1)),
      allDay: allDay,
      timeZone: 'Asia/Shanghai',
      updatedAt: DateTime(2026, 10, 1),
    );

Future<void> _pump(WidgetTester tester, _Repo repo) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 29, 9)),
      ],
      child: lifeTestHost(const Scaffold(body: CalendarListView())),
    ),
  );
  await tester.pumpAndSettle();
  // `AnchorDateNotifier` 没有构造参数，用 notifier.set 把锚点钉在 2026-10，
  // 否则「列表窗口」会随真实日期漂移。
  final container =
      ProviderScope.containerOf(tester.element(find.byType(CalendarListView)));
  container.read(anchorDateProvider.notifier).set(DateTime(2026, 10, 29));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('#399 日历切到 list 档时渲染的是列表视图（接线，不是只有组件）', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo(events: [
      _event('e1', '晨会', DateTime(2026, 10, 29, 9, 30)),
    ]);
    final container = ProviderContainer(overrides: [
      calendarRepositoryProvider.overrideWithValue(repo),
      sidebarPrefsProvider.overrideWith((ref) => null),
    ]);
    addTearDown(container.dispose);
    container.read(anchorDateProvider.notifier).set(DateTime(2026, 10, 29));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: CalendarScaffold(initialViewMode: CalendarViewMode.list),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 只 pump CalendarListView 的用例抓不到「档位还挂在占位符」，这条盯接线。
    expect(find.byKey(const Key('calendar_list_view')), findsOneWidget);
    expect(find.text('列表'), findsNothing);
    expect(find.text('晨会'), findsOneWidget);
  });
  testWidgets('#399 列表视图按日期分组显示日程（不再是一行占位）', (tester) async {
    final repo = _Repo(events: [
      _event('e1', '晨会', DateTime(2026, 10, 29, 9, 30)),
      _event('e2', '评审', DateTime(2026, 10, 29, 14)),
      _event('e3', '明天的会', DateTime(2026, 10, 30, 10)),
    ]);
    await _pump(tester, repo);

    expect(find.byKey(const Key('calendar_list_view')), findsOneWidget);
    expect(find.text('列表'), findsNothing, reason: '占位文本必须消失');

    // 分组头
    expect(find.text('10月29日'), findsOneWidget);
    expect(find.text('10月30日'), findsOneWidget);
    // 行内容与时间
    expect(find.text('晨会'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('明天的会'), findsOneWidget);
  });

  testWidgets('#399 空窗口显示空态而不是白屏', (tester) async {
    await _pump(tester, _Repo(events: []));
    expect(find.byKey(const Key('calendar_list_empty')), findsOneWidget);
  });

  testWidgets('#399 全天事件显示「全天」而不是 00:00', (tester) async {
    final repo = _Repo(events: [
      _event('a1', '全天事件', DateTime(2026, 10, 29), allDay: true),
    ]);
    await _pump(tester, repo);
    expect(find.text('全天'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
  });
}
