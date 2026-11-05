import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

/// TC-CAL-UI-108（#607 档 A 第五批）：1280 宽点一条日程 → 第三栏 Inspector 出现，
/// 且它是**第三栏**而不是浮层——侧栏与主视图仍各自可见、互不重叠。
///
/// 台账原话「不盖住飞书轨」里的「飞书轨」是壳层左轨（apps/life_launcher 才有），
/// feature_calendar 这一层量不到；这包内能被「盖住」的邻居是 240/280 的日历侧栏，
/// 所以这里量三件：Inspector 在树里、侧栏还在树里、两者的水平矩形不相交。
/// 壳层左轨那半边留给 life_launcher 的路由测试，不在本 PR 假装覆盖。
void main() {
  Future<void> pumpAt1280(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(_Repo()),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 26)),
        ],
        child: lifeTestHost(
          const CalendarScaffold(pinnedViewMode: CalendarViewMode.day),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('TC-CAL-UI-108 点日程后第三栏 Inspector 出现，且不盖住日历侧栏', (tester) async {
    await pumpAt1280(tester);
    // 前置：没草稿时第三栏不挂（否则下面的「出现」是恒真）。
    expect(
      find.byKey(const Key('event_inspector_pane')),
      findsNothing,
      reason: 'expanded 档无草稿时第三栏不该在树里',
    );
    expect(find.byKey(const Key('calendar_sidebar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('day-event-e108')));
    await tester.pumpAndSettle();

    final pane = find.byKey(const Key('event_inspector_pane'));
    expect(pane, findsOneWidget, reason: '点一条日程须打开第三栏 Inspector');
    expect(
      find.byKey(const Key('calendar_sidebar')),
      findsOneWidget,
      reason: '第三栏是加进来的一列，不是把侧栏换掉',
    );

    final paneRect = tester.getRect(pane);
    final sidebarRect = tester.getRect(
      find.byKey(const Key('calendar_sidebar')),
    );
    expect(
      paneRect.left,
      greaterThanOrEqualTo(sidebarRect.right),
      reason: 'Inspector 与侧栏水平不相交，才算「没盖住」',
    );
    expect(
      paneRect.right,
      lessThanOrEqualTo(1280.0),
      reason: 'Inspector 不得溢出窗口右边界',
    );
  });
}

class _Repo implements CalendarRepository {
  static final CalendarEvent _event = CalendarEvent(
    id: 'e108',
    calendarId: 'c108',
    uid: 'u108',
    title: '周会',
    // 墙钟本地、且必须落在时间轴窗口 dayStartHour–dayEndHour(8–18) 内，
    // 否则事件卡在屏幕上根本不渲染，tap 会打空（#553 的教训）。
    startAt: DateTime(2026, 10, 26, 9, 30),
    endAt: DateTime(2026, 10, 26, 10, 30),
    timeZone: 'local',
    updatedAt: DateTime.utc(2026, 10, 20),
  );

  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(const [
    Calendar(id: 'c108', title: '工作', colorArgb: 0xFF007AFF, isDefault: true),
  ]);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) {
    return Stream.value([_event]);
  }

  @override
  Future<CalendarEvent?> getEvent(String id) async =>
      id == _event.id ? _event : null;

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
