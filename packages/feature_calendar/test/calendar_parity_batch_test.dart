import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

/// 对等回归批次：#168 / #177 / #178 / #188。
void main() {
  group('#168 锚点与「今天」', () {
    test('today() 把锚点重置到今天零点', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(anchorDateProvider.notifier)
          .set(DateTime(2026, 11, 20, 18, 30));

      container.read(anchorDateProvider.notifier).today();

      final now = DateTime.now();
      final anchor = container.read(anchorDateProvider);
      expect(
        [anchor.year, anchor.month, anchor.day],
        [now.year, now.month, now.day],
        reason: 'today() 必须真正写回 state（旧实现丢弃了 build() 返回值）',
      );
      expect(anchor.hour, 0);
      expect(anchor.minute, 0);
    });
  });

  group('#177 标题必填提示', () {
    late _Repo repo;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
      repo = _Repo();
      container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          sidebarPrefsProvider.overrideWith((ref) => null),
          kalenderEventsControllerProvider.overrideWithValue(
            kalender.DefaultEventsController(),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    Future<void> pumpInspector(WidgetTester tester, CalendarEvent event) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(
            Scaffold(
              body: EventInspectorPane(
                initialEvent: event,
                onSaved: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('刚打开不显示「标题不能为空」，点保存后才出现', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpInspector(tester, _event(title: ''));

      expect(
        find.text('标题不能为空'),
        findsNothing,
        reason: '#177：未点保存前不应预判错误',
      );

      await tester.tap(find.byKey(const Key('event_inspector_save')));
      await tester.pumpAndSettle();

      expect(find.text('标题不能为空'), findsOneWidget, reason: '保存尝试后给出提示');
      expect(repo.upserted, isEmpty, reason: '空标题不写库');
    });
  });

  group('#188 行程时间', () {
    late _Repo repo;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
      repo = _Repo();
      container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          sidebarPrefsProvider.overrideWith((ref) => null),
          kalenderEventsControllerProvider.overrideWithValue(
            kalender.DefaultEventsController(),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    testWidgets('点行可选 15 分钟并回显', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(
            Scaffold(
              body: EventInspectorPane(
                initialEvent: _event(title: '周会'),
                onSaved: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('无'), findsWidgets, reason: '默认无行程时间');

      await tester.tap(find.byKey(const Key('event_field_travel_dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('5 分钟'), findsOneWidget);
      expect(find.text('120 分钟'), findsOneWidget);

      await tester.tap(find.text('15 分钟'));
      await tester.pumpAndSettle();

      expect(find.text('15 分钟'), findsOneWidget, reason: '选择后行内回显');
    });
  });

  group('#178 紧凑档工具栏', () {
    testWidgets('有「今天」与视图切换，且标题随视图变化', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(
            const Scaffold(body: CalendarToolbar(compact: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar_today_button')), findsOneWidget);
      expect(find.byKey(const Key('calendar_view_mode_menu')), findsOneWidget);

      container.read(anchorDateProvider.notifier).set(DateTime(2026, 11, 20));
      await tester.pumpAndSettle();
      expect(find.text('11月20日'), findsOneWidget, reason: '日视图标题含月日');

      await tester.tap(find.byKey(const Key('calendar_today_button')));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final anchor = container.read(anchorDateProvider);
      expect([anchor.year, anchor.month, anchor.day], [
        now.year,
        now.month,
        now.day,
      ]);

      await tester.tap(find.byKey(const Key('calendar_view_mode_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calendar_view_mode_week')));
      await tester.pumpAndSettle();
      expect(container.read(viewModeProvider), CalendarViewMode.week);
    });
  });
}

CalendarEvent _event({required String title}) => CalendarEvent(
  id: kDraftEventId,
  calendarId: 'c1',
  uid: 'u1',
  title: title,
  startAt: DateTime.utc(2026, 10, 24, 10),
  endAt: DateTime.utc(2026, 10, 24, 11),
  timeZone: 'UTC',
  updatedAt: DateTime.utc(2026, 10, 24),
);

class _Repo implements CalendarRepository {
  final List<CalendarEvent> upserted = [];
  final List<Calendar> calendars = [];
  final List<CalendarEvent> visible = [];
  final _eventController = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield List<CalendarEvent>.unmodifiable(visible);
    yield* _eventController.stream;
  }

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(calendars);
  }

  @override
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    upserted.add(e);
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
