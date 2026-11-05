import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

/// TC-CAL-UI-107（#607 档 A 第二批）：☰ 隐藏侧栏 = 消失 → 再点恢复 → 重启保持。
///
/// 台账原状「手动（三端走查）」的三句话各对应一面：
/// ①「点隐藏 → 侧栏消失」与 ②「再点恢复」用真实工具栏入口（tap `calendar_sidebar_toggle`）
/// 量 `calendar_sidebar` 在树里的有无；③「重启后保持（读 preference 键）」用同一份
/// mock prefs 建第二个容器重挂骨架，量它读回第一次的选择不回落「显示」。
/// 之前 #254 只在 provider 层证过持久化，界面这条路从没走过——组合根漏注入 prefs
/// 那种坏法（provider 层测试照样绿）只有从入口点下去才拦得住。
void main() {
  Future<void> pumpDesktop(WidgetTester tester, ProviderContainer container) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(const CalendarScaffold()),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerWith(SharedPreferences? prefs) {
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(_NoopRepo()),
        if (prefs != null) sidebarPrefsProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Finder sidebar = find.byKey(const Key('calendar_sidebar'));
  Finder toggle = find.byKey(const Key('calendar_sidebar_toggle'));

  testWidgets('TC-CAL-UI-107 半边①②：点 ☰ 侧栏消失，再点恢复', (tester) async {
    await pumpDesktop(tester, containerWith(null));
    expect(sidebar, findsOneWidget, reason: '桌面档默认显示侧栏');
    expect(toggle, findsOneWidget, reason: '☰ 入口须有 Key，否则本用例退成恒真');

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(sidebar, findsNothing, reason: '点隐藏后侧栏还在=没接到偏好');
    // 灵敏度对照：侧栏没了但入口仍在，证明上一条量的是「侧栏显隐」而不是整条工具栏消失。
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(sidebar, findsOneWidget, reason: '再点须恢复');
  });

  testWidgets('TC-CAL-UI-107 半边③：☰ 隐藏后重建容器仍隐藏（重启保持）', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();

    await pumpDesktop(tester, containerWith(prefs));
    expect(sidebar, findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(sidebar, findsNothing);
    await prefs.reload();

    // 重挂：同一份 prefs 的第二个容器 = 应用重启后读偏好。
    await pumpDesktop(tester, containerWith(prefs));
    expect(
      sidebar,
      findsNothing,
      reason: '新容器读回「显示」= ☰ 这条路没落盘（#254 的组合根漏注入形态）',
    );
    expect(
      prefs.getBool('lifeos.calendar.sidebar.visible'),
      isFalse,
      reason: '偏好键须与契约一致且值为 false',
    );
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
