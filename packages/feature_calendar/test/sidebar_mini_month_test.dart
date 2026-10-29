// #383 / TC-CAL-UI-122 补强：侧栏必须有**迷你月历**（Apple 日历侧栏底部）。
//
// 背景：`MiniMonth` 组件（契约 §5.4 / F-04）早已存在，但全仓 **0 处实例化**——
// `#22` 关单时以为接了，真机上侧栏一路空白到底。本测试盯住「挂载 + 可交互」。
import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/life_test_app.dart';

class _Repo implements CalendarRepository {
  final List<Calendar> list = [];
  final _controller = StreamController<List<Calendar>>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(list);
    yield* _controller.stream;
  }

  @override
  Future<void> upsertCalendar(Calendar c) async {
    final i = list.indexWhere((e) => e.id == c.id);
    if (i >= 0) {
      list[i] = c;
    } else {
      list.add(c);
    }
    _controller.add(List<Calendar>.unmodifiable(list));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Repo> _pumpSidebar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = _Repo();
  await repo.upsertCalendar(const Calendar(
    id: 'c1',
    title: '工作',
    colorArgb: 0xFF007AFF,
  ));
  // 不设 mock 会让 getInstance() 卡在平台通道上（测试里直接挂住）。
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWithValue(prefs),
      ],
      child: lifeTestHost(const Scaffold(body: CalendarSidebar())),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('#383 侧栏挂载了迷你月历（此前组件存在但 0 实例）', (tester) async {
    await _pumpSidebar(tester);
    expect(find.byKey(const Key('calendar_sidebar_mini_month')), findsOneWidget);
    expect(find.byType(MiniMonth), findsOneWidget);
  });

  testWidgets('#383 迷你月历点日期改锚点（可交互，不是死图）', (tester) async {
    await _pumpSidebar(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CalendarSidebar)),
    );
    final before = container.read(anchorDateProvider);

    // 点「15」：侧栏月历当前显示 2026-10（锚点由夹具挂钟决定）
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();

    final anchor = container.read(anchorDateProvider);
    expect(before, isNotNull, reason: '夹具应已注入锚点');
    expect(anchor.year, 2026);
    expect(anchor.month, 10);
    expect(anchor.day, 15);
  });

  testWidgets('#383 迷你月历周标题是中文（不得残留 Tue 等英文缩写）', (tester) async {
    await _pumpSidebar(tester);
    // TableCalendar 默认走 intl，未初始化时给英文；这里必须已本地化
    for (final en in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(en), findsNothing, reason: '侧栏不得出现英文星期缩写 $en');
    }
    expect(find.text('一'), findsWidgets, reason: '周标题应为中文');
  });
}
