// #628：`CalendarScaffold(pinnedViewMode:)` 是钉死，不是初始值——改名之后把两件事钉住：
// ① 不钉（生产侧的常态：全仓生产代码一处都不传）时档位跟随 `viewModeProvider`；
// ② 钉住时视图不跟随 provider，这是**声明过的行为**，不是名字撒谎。
//
// 改名前它是 `initialViewMode ?? watch(viewModeProvider)`：名字叫「初始」，
// 传了值就永远等于那个值。#616 补档位入口时正是被它挡住——provider 变了、视图不动，
// 看起来像「入口没生效」。
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required ProviderContainer container,
    CalendarViewMode? pinned,
  }) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(CalendarScaffold(pinnedViewMode: pinned)),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer newContainer() {
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(_NoopRepo()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 29, 9)),
        // 与 day_week_view_test 同口径：换档会把日历视图连根换掉，
        // 共用默认 EventsController 时旧视图的监听会在停用后收到通知
        // （`Looking up a deactivated widget's ancestor is unsafe`），
        // 每个容器发一个自己的控制器。
        kalenderEventsControllerProvider.overrideWithValue(
          kalender.DefaultEventsController(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // 用年档做切换目标：月档那条路径会撞 https://gitea.zh04.com/izhaong/zh-cloud-lifeos-flutter/issues/632
  // （`month_view.dart:95` 在 build 里 `replaceEvents` ⇒ 旧日视图停用时收到控制器通知，
  // 报 `Looking up a deactivated widget's ancestor is unsafe`）。那是另一个缺陷，
  // 不该混进本单的改名里，所以这里选一条不共用 kalender 控制器的档位。
  testWidgets('不钉档时视图跟随 viewModeProvider（播种入口就是它）', (tester) async {
    final container = newContainer();
    await pump(tester, container: container);
    expect(find.byKey(const Key('calendar_day_view')), findsOneWidget);

    container.read(viewModeProvider.notifier).set(CalendarViewMode.year);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar_year_view')),
      findsOneWidget,
      reason: 'provider 改了视图没改 = 又回到「名字说初始、行为是钉死」',
    );
  });

  testWidgets('钉住档时行为与名字一致：provider 变了视图不动', (tester) async {
    final container = newContainer();
    await pump(tester, container: container, pinned: CalendarViewMode.day);
    expect(find.byKey(const Key('calendar_day_view')), findsOneWidget);

    container.read(viewModeProvider.notifier).set(CalendarViewMode.year);
    await tester.pumpAndSettle();

    // 这条不是「应该被修好」的坏行为，而是 pinnedViewMode 声明出来的语义：
    // 要起始档且仍可切换，请走上一条用例的播种路径，别用这个参数。
    expect(container.read(viewModeProvider), CalendarViewMode.year);
    expect(find.byKey(const Key('calendar_day_view')), findsOneWidget);
    expect(find.byKey(const Key('calendar_year_view')), findsNothing);
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
  }) =>
      Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
