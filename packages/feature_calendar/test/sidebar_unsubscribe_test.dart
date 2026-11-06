// #655 / 矩阵 C3「退订」与 J4「移除节假日日历」：ⓘ 面板的删除动作此前只按
// `CalendarKind.local` 一档断言过（`calendar_sidebar_test.dart` 的
// TC-CAL-UI-121/127 用 `cal-info-c1`，c1 是 local）。订阅与节假日两行走的是
// 同一条链（`_openDetail` ⇒ `_CalendarEditDialog(calendar:)` ⇒ `isEdit=true`
// ⇒ `detail-delete` ⇒ `deleteCalendar(id)`，按 kind 无分叉），但没人按过。
import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/life_test_app.dart';

void main() {
  Future<_Repo> pumpSidebar(WidgetTester tester, Calendar seed) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _Repo();
    await repo.upsertCalendar(seed);
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
    return repo;
  }

  /// 侧栏行 ⓘ ⇒ 详情弹层 ⇒ 「删除」——Apple 的退订/移除就是这一条。
  Future<void> deleteViaInfoPanel(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(Key('cal-info-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-delete')));
    await tester.pumpAndSettle();
  }

  testWidgets('TC-CAL-UI-224 订阅日历的 ⓘ ⇒ 删除 = 退订', (tester) async {
    final repo = await pumpSidebar(
      tester,
      const Calendar(
        id: 'sub1',
        title: 'RSS 日历',
        colorArgb: 0xFFAF52DE,
        kind: CalendarKind.subscription,
        sourceUrl: 'https://example.com/feed.ics',
      ),
    );
    expect(
      find.byKey(const Key('cal-info-sub1')),
      findsOneWidget,
      reason: '订阅行没渲出来 ⇒ 后面两条断言都会恒真',
    );

    await deleteViaInfoPanel(tester, 'sub1');

    expect(repo.deleted, ['sub1'], reason: 'C3：退订必须打到 deleteCalendar(sub1)');
    expect(
      find.byKey(const Key('cal-info-sub1')),
      findsNothing,
      reason: '退订后该行从侧栏消失',
    );
  });

  testWidgets('TC-CAL-UI-225 节假日日历的 ⓘ ⇒ 删除 = 移除节假日日历', (tester) async {
    final repo = await pumpSidebar(
      tester,
      const Calendar(
        id: kHolidayCalendarId,
        title: kHolidayCalendarTitle,
        colorArgb: kHolidayColorArgb,
        kind: CalendarKind.holiday,
      ),
    );
    expect(
      find.byKey(const Key('cal-info-$kHolidayCalendarId')),
      findsOneWidget,
      reason: '节假日行没渲出来 ⇒ 后面两条断言都会恒真',
    );
    // 节假日日历已存在时，那条「未订阅入口」固定行让位给分组内的同构行（#281）；
    // 先钉住这一点，下面「入口回来了」才不是恒真。
    expect(
      find.byKey(const Key('sidebar_holidays_toggle')),
      findsNothing,
      reason: '已存在节假日日历时不该同时出现入口行',
    );

    await deleteViaInfoPanel(tester, kHolidayCalendarId);

    expect(repo.deleted, [
      kHolidayCalendarId,
    ], reason: 'J4：移除必须打到 deleteCalendar(calendar.holiday.cn)');
    // 「中国大陆节假日」这段文字移除后仍在——那是 J4 之后回到「未订阅入口」那一行
    // （`sidebar_holidays_toggle`，:111 的 `calendars.every(...)` 条件），不是残留。
    // 所以可观测的是**行的形态换了**：ⓘ 按钮没了，入口行回来了。
    expect(
      find.byKey(const Key('cal-info-$kHolidayCalendarId')),
      findsNothing,
      reason: '移除后不再是普通日历行',
    );
    expect(
      find.byKey(const Key('sidebar_holidays_toggle')),
      findsOneWidget,
      reason: '移除后回到「未订阅」入口行（可再打开）',
    );
  });
}

class _Repo implements CalendarRepository {
  final List<Calendar> list = [];
  final List<String> deleted = [];
  final _c = StreamController<List<Calendar>>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(list);
    yield* _c.stream;
  }

  @override
  Future<void> upsertCalendar(Calendar cal) async {
    final i = list.indexWhere((e) => e.id == cal.id);
    if (i >= 0) {
      list[i] = cal;
    } else {
      list.add(cal);
    }
    _c.add(List<Calendar>.unmodifiable(list));
  }

  @override
  Future<void> deleteCalendar(String id) async {
    list.removeWhere((e) => e.id == id);
    deleted.add(id);
    _c.add(List<Calendar>.unmodifiable(list));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
