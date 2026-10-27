import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

/// F-14 设置、农历开关与周数（TC-CAL-UI-210～214；契约 §2.9）。
void main() {
  group('设置面板', () {
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

    Future<void> pumpSettings(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(const Scaffold(body: CalendarSettingsSheet())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('TC-CAL-UI-210 四个区', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpSettings(tester);

      expect(find.byKey(const Key('settings_section_general')), findsOneWidget);
      expect(
        find.byKey(const Key('settings_section_reminders')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings_section_advanced')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings_section_account')), findsOneWidget);
    });

    testWidgets('TC-CAL-UI-211 每周天数 → 5 且视图配置同步', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('settings_week_view_days')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('周一至周五').last);
      await tester.pumpAndSettle();

      expect(repo.pref.weekViewDays, 5);
      expect(
        container.read(calendarViewConfigurationsProvider).week.numberOfDays,
        5,
        reason: '周视图立即变 5 列',
      );
    });

    testWidgets('TC-CAL-UI-214 账户区只在本机、无密码框', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpSettings(tester);

      expect(find.textContaining('只在本机'), findsOneWidget);
      final textFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(textFields.where((f) => f.obscureText), isEmpty, reason: '没有密码框');
    });
  });

  group('默认提醒与时区开关', () {
    testWidgets('TC-CAL-UI-212 新定时日程带默认 -15 提醒', (tester) async {
      final repo = _Repo(
        pref: const CalendarPreference(defaultAlertTimedMinutes: -15),
      );
      final container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          sidebarPrefsProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);

      final draft = CalendarEvent(
        id: kDraftEventId,
        calendarId: 'c1',
        uid: 'u1',
        title: '周会',
        startAt: DateTime.utc(2026, 10, 24, 2),
        endAt: DateTime.utc(2026, 10, 24, 3),
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 24),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(
            Scaffold(
              body: EventInspectorPane(
                initialEvent: draft,
                onSaved: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event_inspector_save')));
      await tester.pumpAndSettle();

      final saved = repo.upserted.single;
      expect(saved.alerts.single.offsetMinutes, -15);
    });

    testWidgets('TC-CAL-UI-213 关掉时区支持 → Inspector 不显示浮动时间', (tester) async {
      final repo = _Repo(pref: const CalendarPreference(timeZoneSupport: true));
      final container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          sidebarPrefsProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(const Scaffold(body: CalendarSettingsSheet())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_time_zone_support')));
      await tester.pumpAndSettle();
      expect(repo.pref.timeZoneSupport, isFalse);

      // 表单跟随偏好：浮动时间开关消失
      final event = CalendarEvent(
        id: 'e1',
        calendarId: 'c1',
        uid: 'u1',
        title: '周会',
        startAt: DateTime.utc(2026, 10, 24, 2),
        endAt: DateTime.utc(2026, 10, 24, 3),
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 24),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(
            Scaffold(
              body: EventFormFields(event: event, onChanged: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event_field_floating')), findsNothing);
    });
  });
}

class _Repo implements CalendarRepository {
  _Repo({this.pref = const CalendarPreference()});

  CalendarPreference pref;
  final List<CalendarEvent> upserted = [];
  final _pref = StreamController<CalendarPreference>.broadcast();
  final _events = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield List<CalendarEvent>.unmodifiable(upserted);
    yield* _events.stream;
  }

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield const <Calendar>[];
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield pref;
    yield* _pref.stream;
  }

  @override
  Future<void> savePreference(CalendarPreference p) async {
    pref = p;
    _pref.add(p);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
