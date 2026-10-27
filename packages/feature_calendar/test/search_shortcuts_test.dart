import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'support/life_test_app.dart';

/// F-13 搜索与快捷键（TC-CAL-UI-171/501/502；契约 §8.4）。
void main() {
  CalendarEvent event(
    String id,
    String title, {
    String? location,
    String? notes,
  }) => CalendarEvent(
    id: id,
    calendarId: 'c1',
    uid: id,
    title: title,
    location: location,
    notes: notes,
    startAt: DateTime.utc(2026, 10, 24, 2),
    endAt: DateTime.utc(2026, 10, 24, 3),
    timeZone: 'UTC',
    updatedAt: DateTime.utc(2026, 10, 24),
  );

  group('搜索', () {
    test('TC-CAL-UI-171 标题/地点/备注三路命中', () {
      expect(matchesCalendarSearch(event('e1', '牙医'), '牙医'), isTrue);
      expect(
        matchesCalendarSearch(event('e2', '周会', location: '牙医诊所'), '牙医'),
        isTrue,
      );
      expect(
        matchesCalendarSearch(event('e3', '复盘', notes: '带牙医报告'), '牙医'),
        isTrue,
      );
      expect(matchesCalendarSearch(event('e1', '牙医'), ''), isTrue);
      expect(matchesCalendarSearch(event('e1', '牙医'), '长跑'), isFalse);
    });

    testWidgets('TC-CAL-UI-171 月视图只剩命中项，清空恢复', (tester) async {
      final repo = _Repo()
        ..events.addAll([
          event('e1', '牙医'),
          event('e2', '周会', location: '牙科室'),
        ]);
      final controller = kalender.DefaultEventsController();
      final container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          sidebarPrefsProvider.overrideWith((ref) => null),
          kalenderEventsControllerProvider.overrideWithValue(controller),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(anchorDateProvider.notifier)
          .set(DateTime.utc(2026, 10, 24));
      container.read(searchQueryProvider.notifier).set('牙医');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(
            Scaffold(
              body: CalendarMonthView(
                viewCallbacks: CalendarViewCallbacks(
                  repo: repo,
                  preference: const CalendarPreference(),
                  setDraft: (_) {},
                ),
                eventsController: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('牙医'), findsOneWidget);
      expect(find.text('周会'), findsNothing, reason: '标题不含关键词');

      container.read(searchQueryProvider.notifier).set('');
      await tester.pumpAndSettle();
      expect(find.text('周会'), findsOneWidget, reason: '清空后恢复');
    });

    testWidgets('工具栏搜索框写入 query', (tester) async {
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(const Scaffold(body: CalendarToolbar())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calendar_search_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calendar_search_field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('calendar_search_field')),
        '牙医',
      );
      await tester.pump();
      expect(container.read(searchQueryProvider), '牙医');

      await tester.tap(find.byKey(const Key('calendar_search_close')));
      await tester.pumpAndSettle();
      expect(container.read(searchQueryProvider), '');
      expect(container.read(searchActiveProvider), isFalse);
    });
  });

  group('快捷键', () {
    test('TC-CAL-UI-501 绑定表覆盖契约 §8.4', () {
      final bindings = calendarShortcutBindings();
      for (final activator in [
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true),
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true),
        const SingleActivator(LogicalKeyboardKey.digit3, meta: true),
        const SingleActivator(LogicalKeyboardKey.digit4, meta: true),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
        const SingleActivator(LogicalKeyboardKey.keyT, meta: true),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true),
        const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true),
        const SingleActivator(LogicalKeyboardKey.keyE, meta: true),
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true, alt: true),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true),
      ]) {
        expect(
          bindings.containsKey(activator),
          isTrue,
          reason: '缺少绑定 $activator',
        );
      }
      expect(
        calendarUnmodifiedShortcutBindings().containsKey(
          const SingleActivator(LogicalKeyboardKey.delete),
        ),
        isTrue,
        reason: 'Delete（重复弹作用域）',
      );
      expect(
        sidebarShortcutBindings().containsKey(
          const SingleActivator(LogicalKeyboardKey.space),
        ),
        isTrue,
        reason: 'Space 侧栏勾选',
      );
    });

    testWidgets('TC-CAL-UI-502 NewEventIntent 触发快速事件', (tester) async {
      var opened = 0;
      late BuildContext innerContext;
      await tester.pumpWidget(
        lifeTestHost(
          CalendarShortcutActions(
            onNewEvent: () => opened++,
            child: Builder(
              builder: (context) {
                innerContext = context;
                return const Scaffold(body: Text('body'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Actions.invoke(innerContext, const NewEventIntent());
      await tester.pump();
      expect(opened, 1);
    });
  });
}

class _Repo implements CalendarRepository {
  final List<CalendarEvent> events = [];
  final List<Calendar> calendars = const [
    Calendar(id: 'c1', title: '工作', colorArgb: 0xFF007AFF),
  ];
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
    yield calendars;
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
    yield* const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
