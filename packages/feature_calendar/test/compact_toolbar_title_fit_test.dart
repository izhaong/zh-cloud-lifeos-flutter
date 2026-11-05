// #627：375 紧凑档工具栏在「2026年10月」这种长标题下横向溢出 0.18px（develop 存量）。
//
// 由来：#612 给紧凑档加月条时，月档那条不变量用例被这条渲染异常先判红
// （`compact_month_strip_test.dart` 里改用年档绕开，并留了本单的号）。
// 标题不许被砍：Apple 日历 iPhone 档月视图顶部就是「2026年10月」整串，
// 让位应是等比缩小，不是省略号——省掉「月」字就读不出看的是哪个月。
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

void main() {
  /// 生产路径铺法：锚点 2026-10-29、指定视图档，375×800。
  ///
  /// 视图档在 pump 前写进 provider（#628 改名后 `pinnedViewMode` 只用于「锁死不许切」，
  /// 这里要的是「按档渲染」），于是月档不会撞上切档时的 `replaceEvents` 异常（#632），
  /// 红点能干净落在工具栏自己上。
  Future<void> pumpCompact(WidgetTester tester, CalendarViewMode mode) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(_NoopRepo()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 29, 9)),
      ],
    );
    addTearDown(container.dispose);
    container.read(anchorDateProvider.notifier).set(DateTime(2026, 10, 29));
    container.read(viewModeProvider.notifier).set(mode);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(const CalendarScaffold()),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final mode in CalendarViewMode.values) {
    testWidgets('375 紧凑档 ${mode.name} 视图的工具栏不抛渲染异常（#627）', (tester) async {
      await pumpCompact(tester, mode);

      expect(
        tester.takeException(),
        isNull,
        reason: '工具栏一行放不下就判红：日/周/列表/月/年五档的标题都得在 359 宽里站住',
      );
    });
  }

  testWidgets('月档让位靠缩小，标题整串仍在且不省略（#627）', (tester) async {
    await pumpCompact(tester, CalendarViewMode.month);
    expect(tester.takeException(), isNull);

    final finder = find.descendant(
      of: find.byKey(const Key('calendar_toolbar')),
      matching: find.text('2026年10月'),
    );
    expect(finder, findsOneWidget);
    final title = tester.widget<Text>(finder);
    expect(
      title.overflow,
      isNot(TextOverflow.ellipsis),
      reason: '省略号会把「月」字砍掉，读屏与肉眼都读不出看的是哪个月',
    );
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
