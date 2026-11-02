// #552：月视图星期表头的标签必须由「周起始日 + 列序号」决定，不能向库要日期。
//
// kalender 0.33 的 MonthHeader 用 `visibleDateTimeRange.start.add(Duration(days: index))`
// 生成 7 个表头日期 —— `Duration` 是绝对时长，跨美国东部 2026-11-01 的回拨日时
// 本地日期会重复一天、少一天。
//
// 修复前在本机（进程时区 America/New_York）实测，同样夹具判红：
//   Expected: ['日','一','二','三','四','五','六']
//     Actual: ['日','日','一','二','三','四','五']        ← 两个周日、没有周六
//   以及 Found 2 widgets with text "日" … ambiguously found multiple matching widgets
//   （key month_weekday_7 出现两次 —— 同一缺陷的另一种问法）。
//
// 周起始日走 `calendarLocaleTagProvider` 钉：`en_US` → 周日为始，`fr_FR` → 周一为始
// （CLDR 与「intl 未初始化时回落周一」两种口径下都落在周一，所以两侧都确定）。
// 不用 `CalendarPreference.startWeekOn`：月视图在 initState 一次性读偏好流，
// 夹具里那一层还没出值 ⇒ 另立单追（见 PR 正文「顺带发现」）。
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

class _Repo implements CalendarRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _header = find.byKey(const Key('month_weekday_header'));

/// 挂钟钉在 2026-11-01：美国东部的回拨日，且当天是周日。
final _now = DateTime(2026, 11, 1, 12);

Future<void> _pumpMonth(WidgetTester tester, String localeTag) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final repo = _Repo();
  final controller = kalender.DefaultEventsController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWithValue(prefs),
        kalenderEventsControllerProvider.overrideWithValue(controller),
        clockProvider.overrideWithValue(() => _now),
        calendarLocaleTagProvider.overrideWithValue(localeTag),
      ],
      child: lifeTestHost(
        Scaffold(
          body: CalendarMonthView(
            viewCallbacks: CalendarViewCallbacks(
              repo: repo,
              preference: const CalendarPreference(),
              setDraft: (draft) {},
            ),
            eventsController: controller,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 表头 7 个格子的标签，按**列序**（左到右）读，而不是按 widget 树顺序。
List<String> _labelsLeftToRight(WidgetTester tester, {Finder? scope}) {
  final cells = find.descendant(
    of: scope ?? _header,
    matching: find.byType(Text),
  );
  final count = cells.evaluate().length;
  final pairs = <(double, String)>[];
  for (var i = 0; i < count; i++) {
    final one = cells.at(i);
    final text = (tester.widget(one) as Text).data ?? '';
    if (!kMonthWeekdayNames.contains(text)) continue;
    pairs.add((tester.getRect(one).left, text));
  }
  pairs.sort((a, b) => a.$1.compareTo(b.$1));
  return pairs.map((p) => p.$2).toList();
}

void main() {
  test('#552 列序纯函数：周起始日 → 7 个 ISO 星期，不重复不遗漏', () {
    expect(monthWeekdayHeaderIsoWeekdays(1), [1, 2, 3, 4, 5, 6, 7]);
    expect(monthWeekdayHeaderIsoWeekdays(7), [7, 1, 2, 3, 4, 5, 6]);
    expect(monthWeekdayHeaderIsoWeekdays(6), [6, 7, 1, 2, 3, 4, 5]);
    for (final start in [1, 2, 3, 4, 5, 6, 7]) {
      expect(
        monthWeekdayHeaderIsoWeekdays(start).toSet().length,
        7,
        reason: '起始 $start 时 7 列必须互不相同',
      );
    }
  });

  testWidgets('#552 周日起始（挂钟跨回拨日）：列序应为「日 一 二 三 四 五 六」', (tester) async {
    await _pumpMonth(tester, 'en_US');

    expect(
      _labelsLeftToRight(tester),
      ['日', '一', '二', '三', '四', '五', '六'],
      reason:
          '标签只该由「周起始日 + 列序号」决定。给出两个「日」少一个「六」，'
          '就是说它跟着库给的日期走，而那个日期跨回拨日会重复一天',
    );
    for (final iso in [1, 2, 3, 4, 5, 6, 7]) {
      expect(
        find.byKey(ValueKey('month_weekday_$iso')),
        findsOneWidget,
        reason: 'ISO 星期 $iso 那一格应恰好出现一次',
      );
    }
  });

  testWidgets('#552 周一为始：列序应为「一 … 日」', (tester) async {
    await _pumpMonth(tester, 'fr_FR');

    expect(
      _labelsLeftToRight(tester),
      kMonthWeekdayNames,
      reason: 'fr_FR 为周一起始 ⇒ 7 列从左到右是 一..日',
    );
  });

  testWidgets('#552 表头「日」列压在正文今天格那一列上（月视图集成）', (tester) async {
    await _pumpMonth(tester, 'en_US');

    final headerDx = tester
        .getRect(find.descendant(of: _header, matching: find.text('日')))
        .center
        .dx;
    final todayDx = tester
        .getRect(find.byKey(const Key('month-today')))
        .center
        .dx;
    final columnWidth = tester.getRect(_header).width / 7;
    // 容差取 6 逻辑像素，不用半列宽（≈80px）：半列宽那个口子大到能把
    // 「整栏多让出一个 gutter（56px）」放过去——变异探针 P4 就是这么发现的。
    expect(
      (headerDx - todayDx).abs(),
      lessThan(6),
      reason:
          '挂钟 2026-11-01 是周日 ⇒「日」那一列正下方就该是今天的格子，'
          '两者中心应几乎同列（列宽 $columnWidth，容差只给 6px）',
    );
  });

  // 组件级：开周号栏那一支在月视图夹具里点不到（偏好读不到），
  // 所以直接量这个组件——gutter 宽度与 `defaultWeekNumberWidth` 同源，
  // 数字靠探针量出来，不写死。
  testWidgets('#552 开周号栏时留白与 defaultWeekNumberWidth 同值', (tester) async {
    double probedWidth(BuildContext context) =>
        kalender.defaultWeekNumberWidth(context);

    Future<double> leftEdgeOfFirstCell({required bool weekNumbers}) async {
      await tester.pumpWidget(
        lifeTestHost(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 700,
              child: MonthWeekdayHeader(
                firstDayOfWeek: 7,
                showWeekNumbers: weekNumbers,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getRect(find.byKey(const ValueKey('month_weekday_7'))).left;
    }

    final withoutGutter = await leftEdgeOfFirstCell(weekNumbers: false);
    expect(withoutGutter, 0, reason: '不开周号栏时第一格贴左边界（探针的零点）');
    final withGutter = await leftEdgeOfFirstCell(weekNumbers: true);
    final expected = probedWidth(
      tester.element(find.byKey(const ValueKey('month_weekday_7'))),
    );
    expect(
      withGutter - withoutGutter,
      expected,
      reason: '表头留白必须与正文用的同一个宽度解析函数相等，否则 7 列整体错一列',
    );
    expect(_labelsLeftToRight(tester, scope: find.byType(MonthWeekdayHeader)), [
      '日',
      '一',
      '二',
      '三',
      '四',
      '五',
      '六',
    ], reason: '同一夹具里标签列序不变');
  });
}
