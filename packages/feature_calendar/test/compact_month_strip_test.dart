// TC-CAL-UI-201 后半句「有月条」与 TC-CAL-UI-202 的边界（#612）。
//
// 契约 §589 写的是 iPhone 档「**月条**（可下拉展开整月）」，而 `MiniMonth` 是 6 行整月网格、
// 全仓只有侧栏一处挂载（`widgets/calendar_sidebar.dart:196`），compact 档整条侧栏都不挂
// （`calendar_scaffold.dart:197` 的 `if (!compact && sidebarVisible)`）。
// 于是 iPhone 上既没有条也没有月历：201 的第二句在代码里根本没有对象可断言。
// 本文件钉「条」这一半：锚点当月逐日、点某日改锚点；「下拉展开整月」是 202，另单跟。
import 'dart:ui' show Tristate;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

const _strip = Key('calendar_month_strip');

String _chipKey(int day) => 'calendar_month_strip_day_$day';

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

  testWidgets('TC-CAL-UI-201 后半句：375 档有月条，且仍是当月逐日', (tester) async {
    await pumpAt(tester, const Size(375, 800));

    expect(find.byKey(_strip), findsOneWidget);
    // 月条不许把侧栏也挂回来（TC-CAL-UI-201 前半句与 compact_no_sidebar_test 的口径）。
    expect(find.byKey(const Key('calendar_sidebar')), findsNothing);
    // 十月 31 天逐日一格，不多不少（跨进下个月就不是「月条」了）。
    expect(
      find.descendant(of: find.byKey(_strip), matching: find.byType(CupertinoButton)),
      findsNWidgets(31),
    );
    expect(find.byKey(ValueKey(_chipKey(1))), findsOneWidget);
    expect(find.byKey(ValueKey(_chipKey(31))), findsOneWidget);
  });

  testWidgets('月条点某日改锚点，选中态读屏读得出来', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAt(tester, const Size(375, 800));

    final chip = find.byKey(ValueKey(_chipKey(12)));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    final anchor = container.read(anchorDateProvider);
    expect([anchor.year, anchor.month, anchor.day], [2026, 10, 12]);
    // 紧凑档标题跟着锚点走：证明改的是「看哪天」而不是只画了个选中态。
    expect(find.text('10月12日'), findsOneWidget);

    final data = tester.getSemantics(chip);
    expect(data.label, contains('10月12日'));
    expect(
      data.flagsCollection.isSelected,
      Tristate.isTrue,
      reason: '选中态只有颜色 ⇒ 读屏读不出选到哪天',
    );
    handle.dispose();
  });

  testWidgets('不变量：compact 年档不挂月条（屏上已是 12 个迷你月，条会重复并白吃 52 高）', (tester) async {
    await pumpAt(tester, const Size(375, 800));

    // 走生产路径切档：紧凑档菜单 → 年。
    // 为什么用年档而不是月档验同一条规则：月档标题「2026年10月」在 375 宽会把工具栏
    // 撑溢出 0.18px（develop 存量，见 #627），那条渲染异常会先于本断言把用例判红，
    // 混进本 PR 就成了「月档测不了」。挂载条件对 month/year 是同一个分支。
    await tester.tap(find.byKey(const Key('calendar_view_mode_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_view_mode_year')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar_year_view')), findsOneWidget);
    expect(find.byKey(_strip), findsNothing);

    // 切回日档，条须回来（证明这条判据不是「永远没有」）。
    await tester.tap(find.byKey(const Key('calendar_view_mode_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_view_mode_day')));
    await tester.pumpAndSettle();
    expect(find.byKey(_strip), findsOneWidget);
  });

  testWidgets('对照：medium 档不挂月条（月历仍走侧栏那一份）', (tester) async {
    await pumpAt(tester, const Size(800, 900));

    expect(
      find.byKey(_strip),
      findsNothing,
      reason: '两处同时挂 = 同一份月历渲染两遍',
    );
    expect(find.byKey(const Key('calendar_sidebar')), findsOneWidget);
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
