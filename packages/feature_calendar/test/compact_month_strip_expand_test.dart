// TC-CAL-UI-202（#630）：iPhone 档月条「下拉展开整月」，点某日后收起并跳到那天。
//
// 条本身由 #612 补上（`widgets/month_strip.dart`），但那时只有横滑 + 点日，
// 往下拉没有任何反应 ⇒ 契约 §589「月条（可下拉展开整月）」的后半句没有对象。
// 本文件钉三件事：向下拖能展开、展开态点日会收起并落锚点、横向拖**不许**触发展开
// （条自己要靠横滑选日，阈值若做成「任意拖拽」就把这条能力吃掉了）。
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

const _strip = Key('calendar_month_strip');
const _expanded = Key('calendar_month_strip_expanded');

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

  testWidgets('向下拖月条 ⇒ 展开整月（复用 MiniMonth，不新造第二套月历）', (tester) async {
    await pumpAt(tester, const Size(375, 800));
    // 起手必须是收起态：它既是默认态，也是 golden（iphone_375_*）画的那一态。
    expect(find.byKey(_expanded), findsNothing);

    await tester.drag(find.byKey(_strip), const Offset(0, 60));
    await tester.pumpAndSettle();

    expect(find.byKey(_expanded), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(_expanded), matching: find.byType(MiniMonth)),
      findsOneWidget,
      reason: '展开态是那份现成的迷你月历，不是另画一套（期望 2）',
    );
    // 条不消失：展开是「往下摊开」，不是把条换掉（横滑选日还得回来）。
    expect(find.byKey(_strip), findsOneWidget);
  });

  testWidgets('展开态点某日 ⇒ 收起并把锚点落到那天', (tester) async {
    await pumpAt(tester, const Size(375, 800));
    await tester.drag(find.byKey(_strip), const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(find.byKey(_expanded), findsOneWidget);

    final day = find.descendant(
      of: find.byKey(_expanded),
      matching: find.text('12'),
    );
    expect(day, findsOneWidget);
    await tester.tap(day);
    await tester.pumpAndSettle();

    expect(find.byKey(_expanded), findsNothing, reason: '点完即收起（契约 §589 后半句）');
    final anchor = container.read(anchorDateProvider);
    expect([anchor.year, anchor.month, anchor.day], [2026, 10, 12]);
    // 收起后条回到 29→12 的位置：锚点确实改了，不只是面板关了。
    expect(find.text('10月12日'), findsOneWidget);
  });

  testWidgets('横向拖月条只横滑，不触发展开（阈值不许吃掉选日能力）', (tester) async {
    await pumpAt(tester, const Size(375, 800));

    await tester.drag(find.byKey(_strip), const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(
      find.byKey(_expanded),
      findsNothing,
      reason: '横向角力被展开手势抢走 ⇒ 条就没法横滑选日了',
    );

    // 上面那条行为断言**不具备判别力**：变异实验（给同一个 GestureDetector 也挂上
    // onHorizontalDragUpdate）它照样绿——横向拖拽在角力里被条自己的
    // SingleChildScrollView 拿走，坏法根本走不到回调。所以这条验收改成量结构：
    // 月条的展开手势只声明纵向，横向一个都不挂 ⇒ 它连角力都不进场，抢不走横滑。
    final detector = find.ancestor(
      of: find.byKey(_strip),
      matching: find.byType(GestureDetector),
    );
    expect(detector, findsOneWidget, reason: '月条只该有一处展开手势挂载点');
    final gesture = tester.widget<GestureDetector>(detector);
    expect(gesture.onVerticalDragUpdate, isNotNull);
    expect(
      gesture.onHorizontalDragUpdate,
      isNull,
      reason: '一挂横向回调就进场与条的横滑抢角力（验收 3 的真判据）',
    );
    expect(gesture.onHorizontalDragEnd, isNull);
    expect(gesture.onPanUpdate, isNull, reason: 'pan 不分方向，会同时抢横滑');

    // 反向对照：同一根条上纵向拖是能展开的（证明上一条判据不是「永远不展开」）。
    await tester.drag(find.byKey(_strip), const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(find.byKey(_expanded), findsOneWidget);
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
