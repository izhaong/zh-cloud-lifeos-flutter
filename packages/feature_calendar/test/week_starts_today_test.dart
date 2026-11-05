import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'support/life_test_app.dart';

/// #615：偏好「周从今天开始」的消费方（TC-CAL-UI-110，契约 §8.5）。
///
/// 锚点钉在周三（2026-10-28），开关打开 ⇒ 周视图首列必须是周三。
/// 判据读的是**真交给 kalender 的那个配置对象**（`KalenderView.kalenderController
/// .viewConfiguration`），不是只读我们自己的 provider——否则「provider 算对了、
/// 视图没传下去」这一类缺陷会测不出来。
void main() {
  // 2026-10-28 是周三。
  final wed = DateTime(2026, 10, 28);
  final controller = kalender.DefaultEventsController();
  late _PrefRepo repo;

  CalendarViewCallbacks callbacks() => CalendarViewCallbacks(
    repo: repo,
    preference: repo.preference,
    timeZone: 'UTC',
    setDraft: (_) {},
  );

  Future<void> pumpWeek(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          kalenderEventsControllerProvider.overrideWithValue(controller),
          clockProvider.overrideWithValue(() => wed),
        ],
        child: lifeTestHost(
          Scaffold(
            body: CalendarWeekView(
              viewCallbacks: callbacks(),
              eventsController: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 读真交给 kalender 的首列设置。
  int handedToKalender(WidgetTester tester) {
    final view = tester.widget<kalender.KalenderView>(
      find
          .descendant(
            of: find.byKey(const Key('calendar_week_view')),
            matching: find.byType(kalender.KalenderView),
          )
          .first,
    );
    final config =
        view.kalenderController.viewConfiguration
            as kalender.MultiDayViewConfiguration;
    return config.firstDayOfWeek;
  }

  setUp(() {
    repo = _PrefRepo(const CalendarPreference(weekViewStartsToday: true));
  });

  testWidgets('TC-CAL-UI-110 开「周从今天开始」且今天周三 ⇒ 周视图首列周三', (
    tester,
  ) async {
    await pumpWeek(tester);
    expect(
      handedToKalender(tester),
      DateTime.wednesday,
      reason: '开关打开后首列没变成周三 = 偏好仍然没人消费（本卡要修的就是这个）',
    );
  });

  testWidgets('反向对照：关开关 ⇒ 不覆盖，仍交给 kalender 自己的默认首列', (
    tester,
  ) async {
    repo = _PrefRepo(const CalendarPreference(weekViewStartsToday: false));
    await pumpWeek(tester);
    expect(
      handedToKalender(tester),
      kalender.kDefaultFirstDayOfWeek,
      reason:
          '关闭档必须与本卡之前逐字一致，否则三档 golden 基线被无声改动',
    );
  });

  testWidgets('按设计不覆盖：工作周（5 天档）不跟随开关（#625 裁定选「产品侧接受」）', (
    tester,
  ) async {
    repo = _PrefRepo(
      const CalendarPreference(weekViewStartsToday: true, weekViewDays: 5),
    );
    await pumpWeek(tester);
    expect(
      handedToKalender(tester),
      kalender.kDefaultFirstDayOfWeek,
      reason:
          'kalender-0.33.0 的 MultiDayViewConfiguration.workWeek 把 firstDayOfWeek '
          '写死在 initializer list（不接参数）。#625 裁定不为此换 `custom`——那会把翻页语义'
          '从「按周」改成「按 5 天」，代价盖过收益；改为在设置面写明作用域。'
          '哪天 kalender 放开该参数或我们换实现，这条会自己红。',
    );
  });

}

class _PrefRepo implements CalendarRepository {
  _PrefRepo(this.preference);

  final CalendarPreference preference;
  final _calendars = StreamController<List<Calendar>>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield const <Calendar>[];
    yield* _calendars.stream;
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
  Stream<CalendarPreference> watchPreference() => Stream.value(preference);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
