import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

/// #281：节假日日历只能出现**一次**。
///
/// 未订阅时侧栏底部那条固定行是入口；订阅后它已作为普通日历进入「其他」分组，
/// 固定行必须让位，否则同侧栏两行同名、勾选状态还可能不同步。
void main() {
  late _Repo repo;
  late SharedPreferences prefs;

  Future<void> pump(WidgetTester tester) async {
    // 侧栏是 ListView：窗口太矮时底部固定行不会被 build，先给足高度
    tester.view
      ..physicalSize = const Size(420, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          sidebarPrefsProvider.overrideWithValue(prefs),
        ],
        child: lifeTestHost(const Scaffold(body: CalendarSidebar())),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    prefs = await SharedPreferences.getInstance();
    repo = _Repo();
  });

  testWidgets('未订阅：固定入口行在，且只有一行', (tester) async {
    await repo.upsertCalendar(const Calendar(
      id: 'c1',
      title: '工作',
      colorArgb: 0xFF007AFF,
    ));
    await pump(tester);

    expect(find.text('中国大陆节假日'), findsOneWidget);
    expect(find.byKey(const Key('sidebar_holidays_toggle')), findsOneWidget,
        reason: '未订阅时固定行是唯一入口');
  });

  testWidgets('已订阅：分组行接管，固定行让位（只留一行）', (tester) async {
    await repo.upsertCalendar(const Calendar(
      id: 'c1',
      title: '工作',
      colorArgb: 0xFF007AFF,
    ));
    await repo.upsertCalendar(const Calendar(
      id: kHolidayCalendarId,
      title: kHolidayCalendarTitle,
      colorArgb: kHolidayColorArgb,
      kind: CalendarKind.holiday,
      isVisible: true,
    ));
    await pump(tester);

    expect(
      find.text('中国大陆节假日'),
      findsOneWidget,
      reason: '分组行已存在时不得再渲染固定行（否则侧栏两行同名）',
    );
    expect(find.byKey(const Key('sidebar_holidays_toggle')), findsNothing);
  });
}

/// 最小可变仓库：只支撑侧栏读取。
class _Repo implements CalendarRepository {
  final List<Calendar> calendars = [];
  final _controller = StreamController<List<Calendar>>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(calendars);
    yield* _controller.stream;
  }

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) => Stream.value(const <CalendarEvent>[]);

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(const CalendarPreference());

  @override
  Future<void> upsertCalendar(Calendar c) async {
    calendars.removeWhere((x) => x.id == c.id);
    calendars.add(c);
    _controller.add(List<Calendar>.unmodifiable(calendars));
  }

  @override
  Future<void> setVisibility({
    String? id,
    bool? visible,
    bool? allVisible,
    String? onlyId,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
