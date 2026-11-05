import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

/// TC-CAL-UI-201（#607 档 A 第三批，半边①）：375 宽不挂常驻侧栏。
///
/// 台账这行的期望是两句：「没有左侧常驻侧栏」与「有月条」。这里只钉前一句——
/// 后一句在当前代码里**没有实现**：`MiniMonth` 唯一的挂载点是
/// `widgets/calendar_sidebar.dart:196`，而 compact 档整条侧栏都不挂（`if (!compact && sidebarVisible)`），
/// 所以 iPhone 档根本没有月条。那是产品缺口，另立单跟，不在本 PR 假装断言过。
///
/// 这一句本身有判头：`compact` 是按 `constraints.maxWidth < 600` 现算的（契约 §8.5），
/// 一旦被改成按 `Platform.is*` 分叉，375 宽在桌面上就会被判成宽档、侧栏常驻挤掉主视图。
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(_NoopRepo()),
          // #331 挂钟：钉住「今天」，用例不随执行日期飘。
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 26)),
        ],
        child: lifeTestHost(
          const CalendarScaffold(initialViewMode: CalendarViewMode.day),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('TC-CAL-UI-201 半边①：375 宽没有常驻侧栏，主视图仍占满', (tester) async {
    await pumpAt(tester, const Size(375, 800));
    expect(
      find.byKey(const Key('calendar_sidebar')),
      findsNothing,
      reason: 'compact 档挂侧栏 = 断点判错',
    );
    expect(
      find.byKey(const Key('calendar_sidebar_toggle')),
      findsNothing,
      reason: '☰ 只在 medium/expanded 的宽档工具栏里',
    );
    expect(find.byKey(const Key('calendar_toolbar')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar_day_view')),
      findsOneWidget,
      reason: '主视图须仍在，且不是被侧栏挤没',
    );
    // 主视图宽度须吃满整屏宽，而不是「屏宽 − 240 侧栏」。
    expect(
      tester.getSize(find.byKey(const Key('calendar_day_view'))).width,
      closeTo(375, 1.0),
    );
  });

  // 灵敏度对照：同一份代码在 800 宽（medium）必须挂出侧栏，
  // 否则上面那三条「没有」在两个档位都成立，判不出断点。
  testWidgets('对照：800 宽挂出侧栏与 ☰（断点确实在切）', (tester) async {
    await pumpAt(tester, const Size(800, 900));
    expect(find.byKey(const Key('calendar_sidebar')), findsOneWidget);
    expect(find.byKey(const Key('calendar_sidebar_toggle')), findsOneWidget);
  });
}

class _NoopRepo implements CalendarRepository {
  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(const []);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) {
    return Stream.value(const []);
  }

  @override
  Future<CalendarEvent?> getEvent(String id) async => null;

  @override
  Future<void> upsertCalendar(Calendar c) async {}

  @override
  Future<void> deleteCalendar(String id) async {}

  @override
  Future<void> setDefaultCalendar(String id) async {}

  @override
  Future<void> reorderCalendars(List<String> ids) async {}

  @override
  Future<void> setVisibility({
    String? id,
    bool? visible,
    bool? allVisible,
    String? onlyId,
  }) async {}

  @override
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    return e.id;
  }

  @override
  Future<void> deleteEvent(
    String id, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {}

  @override
  Future<void> moveEvent(String id, String targetCalendarId) async {}

  @override
  Future<List<CalendarEvent>> search(
    String keyword, {
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) async {
    return const [];
  }

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(CalendarPreference.defaults);

  @override
  Future<void> savePreference(CalendarPreference p) async {}
}
