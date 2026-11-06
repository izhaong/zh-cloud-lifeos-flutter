import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

/// #649 / 矩阵 D9：表单「行程时间」的六档取值（5/15/30/60/90/120）+ 归零（无）。
///
/// D6 的 `TC-CAL-UI-132` 只断到「字段存在 + 顺序」，矩阵本行写「六档取值的 UI 断言缺」；
/// 这里补一条把 sheet ⇒ `_copyWith(_e, travelMinutes: minutes)` 与
/// sheet 选「无」 ⇒ `_copyWith(_e, clearTravel: true)` 两条分支都跑一遍，
/// 用 trailing 的可见文案（`${minutes} 分钟` / `无`）当判据。
void main() {
  late _MutableRepo repo;
  late ProviderContainer container;
  final controller = kalender.DefaultEventsController();

  CalendarEvent draft({int? travelMinutes}) => CalendarEvent(
    id: 'e1',
    calendarId: 'c1',
    uid: 'u1',
    title: '周会',
    startAt: DateTime.utc(2026, 10, 24, 10),
    endAt: DateTime.utc(2026, 10, 24, 11),
    timeZone: 'UTC',
    travelMinutes: travelMinutes,
    updatedAt: DateTime.utc(2026, 10, 24),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    controller.clearEvents();
    repo = _MutableRepo();
    container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
        kalenderEventsControllerProvider.overrideWithValue(controller),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpInspector(WidgetTester tester, CalendarEvent event) async {
    // 14 个字段 + 表单头，800×2400 才能把 travel 也拉进渲染树；
    // 与 TC-CAL-UI-132 同档。
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

  Finder travelText(String s) => find.descendant(
    of: find.byKey(const Key('event_field_travel')),
    matching: find.text(s),
  );

  Future<void> pickTravel(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('event_field_travel_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('TC-CAL-UI-221 行程时间六档 + 归零 ⇒ travelMinutes 跟着翻', (tester) async {
    await pumpInspector(tester, draft());
    expect(travelText('无'), findsOneWidget,
        reason: 'TC-CAL-UI-221 初始 travelMinutes==null ⇒ trailing 显示「无」');

    // 六档挨个选中 ⇒ trailing 立刻回显对应文案。sheet 弹层里也有 6 个同名候选，
    // 用 `find.text(...).last` 取 sheet 内那一项（`travelText` 只量字段区内的文案）。
    for (final m in const [5, 15, 30, 60, 90, 120]) {
      await pickTravel(tester, '$m 分钟');
      expect(travelText('$m 分钟'), findsOneWidget,
          reason: '选「$m 分钟」后 event_field_travel 区内 trailing 就是「$m 分钟」');
    }

    // 反向走 clearTravel 那条分支：选「无」 ⇒ `_e.travelMinutes` 回到 null。
    await pickTravel(tester, '无');
    expect(travelText('无'), findsOneWidget,
        reason: '选「无」走 `_copyWith(_e, clearTravel: true)`，trailing 回落到「无」');
  });
}

class _MutableRepo implements CalendarRepository {
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
    visible.add(e);
    _eventController.add(List<CalendarEvent>.unmodifiable(visible));
    return e.id;
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
