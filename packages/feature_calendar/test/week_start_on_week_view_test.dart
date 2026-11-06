import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'support/life_test_app.dart';

/// #639：「每周起始」（`startWeekOn`）此前在 7 天周视图里没人消费。
///
/// 现读证据（develop `33d465e`）：`views/day_view.dart` 里 `startWeekOn` 命中 0，
/// 交给 kalender 的首列只有 `config.week.firstDayOfWeek ?? kDefaultFirstDayOfWeek`
/// 一个来源；而 `views/month_view.dart`（命中 1）与 `widgets/mini_month.dart`（命中 2）
/// 都读它 ⇒ 「月历按周日开、周视图按周一开」这种自相矛盾是可重现的。
///
/// 优先级按金标准：Apple 的「周视图从今天开始」是**覆盖**「一周开始于」的
/// （docs `lifeos/calendar/guide/iphone/zh-cn/05-在iPhone上更改日历设置.md:68`），
/// 所以开关开着时今天赢，关掉时才轮到「每周起始」。
void main() {
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

  /// 读真交给 kalender 的首列（与 week_starts_today_test 同口径：
  /// 只看落到第三方配置对象上的值，不看我们自己算的中间量）。
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

  testWidgets('TC-CAL-UI-111 每周起始=周日 ⇒ 7 天周视图首列周日', (tester) async {
    repo = _PrefRepo(
      const CalendarPreference(startWeekOn: 7, weekViewStartsToday: false),
    );
    await pumpWeek(tester);
    expect(
      handedToKalender(tester),
      DateTime.sunday,
      reason:
          '开关关掉时首列仍停在周一 = 偏好没人消费；月历已经按周日开，两处会自相矛盾',
    );
  });

  testWidgets('「跟随系统」这档仍不覆盖 ⇒ golden 基线一格没动', (tester) async {
    repo = _PrefRepo(
      const CalendarPreference(startWeekOn: 0, weekViewStartsToday: false),
    );
    await pumpWeek(tester);
    expect(
      handedToKalender(tester),
      kalender.kDefaultFirstDayOfWeek,
      reason:
          '本卡故意只接显式的 1..7：startWeekOn=0 继续传 null，落点与改前逐字相同。'
          '按区域推导会让周视图在「区域=周日优先」的执行机上换列，'
          '而 ipad_834_week.png 正是在这样的机器上录的 ⇒ 会打红基线。'
          '那一档要连着重录 golden，另单走授权，不混进本卡。',
    );
  });

  testWidgets('两档同时开：「周视图从今天开始」覆盖「每周起始」', (tester) async {
    repo = _PrefRepo(
      const CalendarPreference(startWeekOn: 7, weekViewStartsToday: true),
    );
    await pumpWeek(tester);
    expect(
      handedToKalender(tester),
      DateTime.wednesday,
      reason: '金标准里这个开关是覆盖项，不是与「每周起始」取交集',
    );
  });

  testWidgets('5 天工作周档仍不受影响（#625 裁定：workWeek 不接该参数）', (
    tester,
  ) async {
    repo = _PrefRepo(
      const CalendarPreference(
        startWeekOn: 7,
        weekViewStartsToday: false,
        weekViewDays: 5,
      ),
    );
    await pumpWeek(tester);
    expect(
      handedToKalender(tester),
      kalender.kDefaultFirstDayOfWeek,
      reason: '本单只补 7 天档；5 天档的口径来自 #625，不许被顺手改掉',
    );
  });

  testWidgets('设置面「每周起始」写明作用域与优先级（#639 判据 2）', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = _PrefRepo(const CalendarPreference());
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(const Scaffold(body: CalendarSettingsSheet())),
      ),
    );
    await tester.pumpAndSettle();

    // 读行自己的 subtitle，不用 find.text 全树搜（旁侧文案会把它喂成恒真）。
    final row = tester.widget<LifeSettingsRow>(
      find.byKey(const Key('settings_start_week_on')),
    );
    expect(row.subtitle, contains('周视图'));
    expect(
      row.subtitle,
      contains('以当天为准'),
      reason: '两个开关会互相覆盖，不写在界面上就只能靠用户猜',
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
