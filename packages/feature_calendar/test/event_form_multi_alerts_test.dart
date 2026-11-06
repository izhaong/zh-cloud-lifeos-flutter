import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

/// #651 / 矩阵 G3 多个提醒（C-112）：
/// 表单里「提醒」这一行的多选 dialog 此前只在 `TC-CAL-UI-153/155` 勾了一条
/// `alert_timed_-15`（单条 ⇒ 单条），矩阵 G3 本行写「多提醒增删断言缺」。
/// 这条把「勾两条 ⇒ 保存 ⇒ 显示 2 个 ⇒ 再进去取消一条 ⇒ 保存 ⇒ 显示 1 个」跑完，
/// 顺便验证重开 dialog 时 `_AlertsDialog(initial: _e.alerts)` 那条路径把已有
/// 两条恢复成 checked 态。
void main() {
  late _Repo repo;
  late ProviderContainer container;
  final controller = kalender.DefaultEventsController();

  CalendarEvent draft() => CalendarEvent(
    id: 'e1',
    calendarId: 'c1',
    uid: 'u1',
    title: '周会',
    startAt: DateTime.utc(2026, 10, 24, 10),
    endAt: DateTime.utc(2026, 10, 24, 11),
    timeZone: 'UTC',
    updatedAt: DateTime.utc(2026, 10, 24),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    controller.clearEvents();
    repo = _Repo();
    container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
        kalenderEventsControllerProvider.overrideWithValue(controller),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpInspector(WidgetTester tester) async {
    // 14 字段全展开需要 800×2400，与 TC-CAL-UI-132/219/221 同档。
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
              initialEvent: draft(),
              onSaved: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder alertsTrailing(String label) => find.descendant(
    of: find.byKey(const Key('event_field_alerts')),
    matching: find.text(label),
  );

  Future<void> openAlertsDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('event_field_alerts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alerts_dialog')), findsOneWidget);
  }

  testWidgets('TC-CAL-UI-222 G3 多提醒：勾两条⇒保存⇒「2 个」⇒再进去取消⇒「1 个」', (tester) async {
    await pumpInspector(tester);
    expect(alertsTrailing('无'), findsOneWidget,
        reason: 'TC-CAL-UI-222 初始 alerts=[] ⇒ trailing 是「无」');

    // 打开 ⇒ 勾 -15 和 -60 两条 ⇒ 保存
    await openAlertsDialog(tester);
    await tester.tap(find.byKey(const Key('alert_timed_-15')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alert_timed_-60')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alerts_dialog_save')));
    await tester.pumpAndSettle();

    expect(alertsTrailing('2 个'), findsOneWidget,
        reason: '勾两条后表单 trailing 显示「2 个」（`_e.alerts.length`）');

    // 重开 ⇒ 两条仍在 checked 态 ⇒ 取消 -60 ⇒ 保存
    await openAlertsDialog(tester);
    await tester.tap(find.byKey(const Key('alert_timed_-60')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alerts_dialog_save')));
    await tester.pumpAndSettle();

    expect(alertsTrailing('1 个'), findsOneWidget,
        reason: '取消一条后再保存 ⇒ trailing 回落「1 个」，与 `_e.alerts.length` 一致');
  });
}

class _Repo implements CalendarRepository {
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
    yield const <Calendar>[];
  }

  @override
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
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
