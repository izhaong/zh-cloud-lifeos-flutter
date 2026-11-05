import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

/// TC-CAL-UI-113（#607 档 A 第三批，半边②）：点迷你月历的另一天，日视图跳到那天。
///
/// 半边①「anchorDate 改变」由 `sidebar_mini_month_test.dart` 的
/// TC-CAL-UI-113 用例量（直接读 provider）。这条补的是台账后半句——
/// **日视图跟着翻面**：只有 provider 变了而头部仍画旧日子，用户看到的就是
/// 「点了没反应」，那正是这行用例要防的。
///
/// 点日期限定在 `calendar_sidebar_mini_month` 子树里找：日视图时间轴本身
/// 有 15 点的刻度文本，全树 `find.text('15')` 会被旁侧满足、判不出点的是谁。
void main() {
  Future<void> pumpDesktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(_Repo()),
          sidebarPrefsProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 26)),
        ],
        child: lifeTestHost(
          const CalendarScaffold(initialViewMode: CalendarViewMode.day),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 日视图头部的日期串（`day_view.dart` 里固定为 `yyyy年M月d日`）。
  String headerDate(WidgetTester tester) {
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('day_view_header')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .toList();
    expect(texts, isNotEmpty, reason: '头部没渲染日期=断言恒真');
    return texts.first;
  }

  testWidgets('TC-CAL-UI-113 半边②：迷你月历点 15，日视图头部跟着翻到 10 月 15 日', (tester) async {
    await pumpDesktop(tester);
    expect(headerDate(tester), '2026年10月26日', reason: '夹具挂钟钉在 10-26');

    await tester.tap(
      find
          .descendant(
            of: find.byKey(const Key('calendar_sidebar_mini_month')),
            matching: find.text('15'),
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(
      headerDate(tester),
      '2026年10月15日',
      reason: '锚点改了但日视图头部没跟着翻=「点了没反应」，正是这行用例要防的',
    );
  });

  // 灵敏度对照：不动迷你月历时头部必须仍是 10-26（否则上面的「翻面」是别的因素造成的）。
  testWidgets('对照：不点迷你月历，头部仍是挂钟那天', (tester) async {
    await pumpDesktop(tester);
    await tester.pumpAndSettle();
    expect(headerDate(tester), '2026年10月26日');
  });
}

class _Repo implements CalendarRepository {
  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(const []);

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(CalendarPreference.defaults);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
