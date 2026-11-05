// TC-CAL-UI-206（#613）：iPhone 横屏 ⇒ 主视图变周视图、侧栏不挂。
//
// 判据（写进 docs 契约 §8.5）：可用高 < 可用宽 且 可用高 ≤ 450 且 可用宽 < 1000。
// 三条各挡一种误伤——高<宽 ⇒ 只横过来才生效；高 ≤ 450 ⇒ 桌面窄长窗（900×500）
// 不被当手机（手机横屏后可用高最多就是长边量级，iPhone 15 Pro Max 横屏 932×430）；
// 宽 < 1000 ⇒ iPad 横屏（1024×768）仍走 expanded 三栏，不抢平板形态。
// 方向只从 constraints 推，不引入 Platform.is*；档仍由 WindowSizeClass 一族算。
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(_NoopRepo()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 29, 9)),
      ],
    );
    addTearDown(container.dispose);
    container.read(anchorDateProvider.notifier).set(DateTime(2026, 10, 29));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(const CalendarScaffold()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('812×375（手机横屏段）：日档升为周档，主视图是周视图且不挂侧栏', (tester) async {
    await pumpAt(tester, const Size(812, 375));

    expect(
      container.read(viewModeProvider),
      CalendarViewMode.week,
      reason: '台账那句是「变为周视图」⇒ 档位本身要落到 week，段控件才不会亮着「日」而画一周',
    );
    expect(find.byKey(const Key('calendar_week_view')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar_sidebar')),
      findsNothing,
      reason: '期望写的是「侧栏不挂」——手机横屏没有桌面缩样',
    );
  });

  testWidgets('对照：375×812（同一台手机竖屏）仍是日档 + 无侧栏', (tester) async {
    await pumpAt(tester, const Size(375, 812));

    expect(container.read(viewModeProvider), CalendarViewMode.day);
    expect(find.byKey(const Key('calendar_day_view')), findsOneWidget);
    expect(find.byKey(const Key('calendar_sidebar')), findsNothing);
  });

  testWidgets('对照：900×500（宽>高但高 500，不是手机段）不升周档、侧栏照挂', (tester) async {
    await pumpAt(tester, const Size(900, 500));

    expect(
      container.read(viewModeProvider),
      CalendarViewMode.day,
      reason: '少了「高 ≤ 450」这上限，桌面拉个窄长窗就会被判成手机横屏（判据里那条上限的绑定测试）',
    );
    expect(find.byKey(const Key('calendar_week_view')), findsNothing);
    expect(find.byKey(const Key('calendar_sidebar')), findsOneWidget);
  });

  testWidgets('对照：800×900（medium 竖屏）仍挂侧栏——与 compact_no_sidebar_test 不打脸', (tester) async {
    await pumpAt(tester, const Size(800, 900));

    expect(find.byKey(const Key('calendar_sidebar')), findsOneWidget);
    expect(find.byKey(const Key('calendar_week_view')), findsNothing);
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
  }) => Stream.value(const []);

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(const CalendarPreference());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
