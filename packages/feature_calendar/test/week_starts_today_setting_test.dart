import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

/// #625 裁定（第 3 条路：产品侧接受 + 写明作用域）的界面侧断言。
///
/// 本卡原以为「设置面那条开关」已存在，实测**没有**：`weekViewStartsToday`
/// 只在模型/落库/同步层与 `calendarViewConfigurationsProvider` 里出现，
/// `CalendarSettingsSheet` 通篇没有它的行（现读 develop `33d465e`：
/// `packages/feature_calendar/lib/src/widgets/calendar_settings_sheet.dart`
/// 全文 289 行零命中 `weekViewStartsToday`）。也就是说 #615 让偏好「被消费」了，
/// 但用户没有任何入口打开它——金标准 iOS 是「设置 → 日历 → 周视图从今天开始」
/// （docs `lifeos/calendar/guide/iphone/zh-cn/05-…设置.md:68`），我们只能用应用内设置面承接。
///
/// 所以本卡补这条开关，并把**作用域**写进它的副标题：5 天工作周档按设计不跟随
/// （`MultiDayViewConfiguration.workWeek` 不接 `firstDayOfWeek`，改 `custom` 会连带把
/// 分页语义从「按周翻」变成「按 5 天翻」，属对外行为变更）。
void main() {
  // 2026-10-28 是周三，与 week_starts_today_test 同一钉法。
  final wed = DateTime(2026, 10, 28);
  late _Repo repo;
  late ProviderContainer container;

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(const Scaffold(body: CalendarSettingsSheet())),
      ),
    );
    await tester.pumpAndSettle();
  }

  void newContainer() {
    container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => wed),
        sidebarPrefsProvider.overrideWith((ref) => null),
      ],
    );
    addTearDown(container.dispose);
  }

  /// 读设置行自己的副标题，而不是 `find.text` 全树搜——后者会被旁侧文本满足，
  /// 变成一条恒真的判据。
  String? subtitleOf(WidgetTester tester, Key key) {
    final row = tester.widget<LifeSwitchRow>(find.byKey(key));
    return row.subtitle;
  }

  testWidgets('TC-CAL-UI-217 设置面有「周视图从今天开始」开关', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = _Repo();
    newContainer();
    await pumpSettings(tester);

    expect(
      find.byKey(const Key('settings_week_view_starts_today')),
      findsOneWidget,
      reason:
          '偏好有人消费（#615）却没人能打开 ⇒ I11 的「有」只在同步链路成立，'
          '本机新建的日历根本碰不到这个开关',
    );
  });

  testWidgets('副标题写明作用域：只影响 7 天周视图，5 天档按设计不跟随', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = _Repo();
    newContainer();
    await pumpSettings(tester);

    final subtitle = subtitleOf(tester, const Key('settings_week_view_starts_today'));
    expect(
      subtitle,
      contains('7 天'),
      reason: '#625 裁定的界面侧落地：不让用户以为开关全局生效',
    );
    expect(subtitle, contains('周一至周五'));
  });

  testWidgets('打开开关 ⇒ 存偏好，且 7 天档的周视图首列跟到周三', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = _Repo();
    newContainer();
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings_week_view_starts_today')));
    await tester.pumpAndSettle();

    expect(repo.pref.weekViewStartsToday, isTrue);
    expect(
      container.read(calendarViewConfigurationsProvider).week.firstDayOfWeek,
      DateTime.wednesday,
      reason: '开关→偏好→视图配置这条链断一环，I11 就只是「字段存在」',
    );
  });

  testWidgets('反向对照：关掉 ⇒ 不覆盖（`null`，交回 kalender 默认首列）', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = _Repo(pref: const CalendarPreference(weekViewStartsToday: true));
    newContainer();
    await pumpSettings(tester);
    expect(repo.pref.weekViewStartsToday, isTrue);

    await tester.tap(find.byKey(const Key('settings_week_view_starts_today')));
    await tester.pumpAndSettle();

    expect(repo.pref.weekViewStartsToday, isFalse);
    expect(
      container.read(calendarViewConfigurationsProvider).week.firstDayOfWeek,
      isNull,
      reason: '关闭档必须与 #615 之前逐字一致，否则三档 golden 被无声改动',
    );
  });
}

class _Repo implements CalendarRepository {
  _Repo({this.pref = const CalendarPreference()});

  CalendarPreference pref;
  final _pref = StreamController<CalendarPreference>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield const <Calendar>[];
  }

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield const <CalendarEvent>[];
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
