import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F-04 侧栏与迷你月历契约（TC-CAL-UI-120～124/126/127；契约 §5.4/§8.1/§8.5）。
void main() {
  late _MutableRepo repo;
  late SharedPreferences prefs;

  Future<void> pumpSidebar(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(home: Scaffold(body: CalendarSidebar())),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> seed(WidgetTester tester) async {
    prefs = await SharedPreferences.getInstance();
    await repo.upsertCalendar(const Calendar(
        id: 'c1', title: '工作', colorArgb: 0xFF007AFF, kind: CalendarKind.local));
    await repo.upsertCalendar(const Calendar(
        id: 'c2', title: '家庭', colorArgb: 0xFF34C759, kind: CalendarKind.local));
    await repo.upsertCalendar(const Calendar(
        id: 'c3', title: '公司排班', colorArgb: 0xFFAF52DE, kind: CalendarKind.subscription));
    await repo.upsertCalendar(const Calendar(
        id: 'c4', title: '中国大陆节假日', colorArgb: 0xFFFF3B30, kind: CalendarKind.holiday));
    await pumpSidebar(tester);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    repo = _MutableRepo();
  });

  // TC-CAL-UI-122：本地、订阅、节假日各一 → 三组标题「我的日历」「订阅」「其他」
  testWidgets('TC-CAL-UI-122 三组固定分组标题', (tester) async {
    await seed(tester);
    expect(find.text('我的日历'), findsOneWidget);
    expect(find.text('订阅'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('公司排班'), findsOneWidget);
  });

  // TC-CAL-UI-123：两个本地日历设同一 groupName → 组头出现一次，组下两条
  testWidgets('TC-CAL-UI-123 日历组组头', (tester) async {
    prefs = await SharedPreferences.getInstance();
    await repo.upsertCalendar(const Calendar(
        id: 'f1', title: '家庭', colorArgb: 0xFF34C759,
        kind: CalendarKind.local, groupName: '家'));
    await repo.upsertCalendar(const Calendar(
        id: 'f2', title: '个人', colorArgb: 0xFF007AFF,
        kind: CalendarKind.local, groupName: '家'));
    await pumpSidebar(tester);
    expect(find.text('家'), findsOneWidget, reason: '组头只出现一次');
    expect(find.text('家庭'), findsOneWidget);
    expect(find.text('个人'), findsOneWidget);
  });

  // TC-CAL-UI-125：订阅刷新失败（lastRefreshError 非空）→ 该行有警告图标
  testWidgets('TC-CAL-UI-125 订阅刷新失败显示警告图标', (tester) async {
    prefs = await SharedPreferences.getInstance();
    await repo.upsertCalendar(const Calendar(
        id: 'bad',
        title: '失败订阅',
        colorArgb: 0xFFAF52DE,
        kind: CalendarKind.subscription,
        lastRefreshError: '拉取超时'));
    await repo.upsertCalendar(const Calendar(
        id: 'ok',
        title: '正常订阅',
        colorArgb: 0xFF34C759,
        kind: CalendarKind.subscription));
    await pumpSidebar(tester);
    expect(find.byKey(const Key('cal-refresh-error-bad')), findsOneWidget,
        reason: 'lastRefreshError 非空的订阅行要有警告图标');
    expect(find.byKey(const Key('cal-refresh-error-ok')), findsNothing,
        reason: '无错误的订阅行不该出现警告图标');
  });

  // TC-CAL-UI-120：添加日历（名称 + 绿色）→ upsert 捕获 #34C759，侧栏出现
  testWidgets('TC-CAL-UI-120 添加日历对话框', (tester) async {
    await seed(tester);
    await tester.tap(find.text('添加日历'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '新日历');
    await tester.tap(find.byKey(const Key('preset-color-0xFF34C759')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(repo.saved.last.colorArgb, 0xFF34C759);
    expect(repo.saved.last.title, '新日历');
    expect(repo.saved.last.kind, CalendarKind.local);
    expect(find.text('新日历'), findsOneWidget, reason: '侧栏出现新日历');
  });

  // TC-CAL-UI-121/127：详情 ⓘ → 能改色（橙）、改忽略提醒、删除
  testWidgets('TC-CAL-UI-121/127 日历详情', (tester) async {
    await seed(tester);
    await tester.tap(find.byKey(const Key('cal-info-c1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('detail-ignore-alerts')));
    await tester.pumpAndSettle();
    expect(repo.saved.last.ignoreAlerts, isTrue, reason: '忽略提醒落库');

    await tester.tap(find.byKey(const Key('preset-color-0xFFFF9500')));
    await tester.pumpAndSettle();
    expect(repo.saved.last.colorArgb, 0xFFFF9500, reason: 'TC-CAL-UI-121 改色落库');

    await tester.tap(find.byKey(const Key('detail-delete')));
    await tester.pumpAndSettle();
    expect(repo.deleted, contains('c1'));
  });

  // TC-CAL-UI-124：onlyId → visibleCalendarIdsProvider 只含该日历
  testWidgets('TC-CAL-UI-124 只显示这一本', (tester) async {
    prefs = await SharedPreferences.getInstance();
    await repo.upsertCalendar(const Calendar(
        id: 'a', title: 'A', colorArgb: 0xFF007AFF, kind: CalendarKind.local, isVisible: true));
    await repo.upsertCalendar(const Calendar(
        id: 'b', title: 'B', colorArgb: 0xFF34C759, kind: CalendarKind.local, isVisible: true));

    late Set<String> visible;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWithValue(prefs),
      ],
      child: Consumer(builder: (context, ref, _) {
        visible = ref.watch(visibleCalendarIdsProvider);
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();

    await repo.setVisibility(onlyId: 'a');
    await tester.pumpAndSettle();

    expect(visible, {'a'}, reason: '其他日历从主视图消失');
  });

  // TC-CAL-UI-126：kind=shared 与 subscription 图标不同
  testWidgets('TC-CAL-UI-126 共享与订阅图标不同', (tester) async {
    prefs = await SharedPreferences.getInstance();
    await repo.upsertCalendar(const Calendar(
        id: 's1', title: '公司排班', colorArgb: 0xFFAF52DE, kind: CalendarKind.subscription));
    await repo.upsertCalendar(const Calendar(
        id: 'h1', title: '同事共享', colorArgb: 0xFFAF52DE, kind: CalendarKind.shared));
    await pumpSidebar(tester);

    final subIcon = tester.widget<Icon>(find.byIcon(Icons.rss_feed));
    final sharedIcon = tester.widget<Icon>(find.byIcon(Icons.group_outlined));
    expect(subIcon.icon, isNot(sharedIcon.icon));
  });

  // ☰ 切换显隐并持久化（契约：shared_preferences 键 lifeos.calendar.sidebar.visible）
  test('侧栏显隐持久化', () async {
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sidebarPrefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    expect(container.read(sidebarVisibleProvider), isTrue);
    container.read(sidebarVisibleProvider.notifier).toggle();
    expect(container.read(sidebarVisibleProvider), isFalse);
    expect(prefs.getBool('lifeos.calendar.sidebar.visible'), isFalse);
  });

  // 迷你月历：点日期 → anchorDateProvider 变为该日
  testWidgets('迷你月历点日期改锚点', (tester) async {
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      calendarRepositoryProvider.overrideWithValue(repo),
      sidebarPrefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    final anchor = container.read(anchorDateProvider);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: MiniMonth())),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();

    final moved = container.read(anchorDateProvider);
    expect(moved.day, 15);
    expect(moved.month, anchor.month, reason: '同月内跳日');
  });
}

/// 可变假仓库（F-04 侧栏交互；F-05+ 逐步充实）。
class _MutableRepo implements CalendarRepository {
  final List<Calendar> list = [];
  final List<Calendar> saved = [];
  final List<String> deleted = [];
  final _controller = StreamController<List<Calendar>>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(list);
    yield* _controller.stream;
  }

  void _emit() => _controller.add(List.unmodifiable(list));

  @override
  Future<void> upsertCalendar(Calendar c) async {
    final i = list.indexWhere((e) => e.id == c.id);
    if (i >= 0) {
      list[i] = c;
    } else {
      list.add(c);
    }
    saved.add(c);
    _emit();
  }

  @override
  Future<void> deleteCalendar(String id) async {
    list.removeWhere((e) => e.id == id);
    deleted.add(id);
    _emit();
  }

  @override
  Future<void> setVisibility(
      {String? id, bool? visible, bool? allVisible, String? onlyId}) async {
    for (var i = 0; i < list.length; i++) {
      if (onlyId != null) {
        list[i] = _copyWithVisible(list[i], list[i].id == onlyId);
      } else if (allVisible != null) {
        list[i] = _copyWithVisible(list[i], allVisible);
      } else if (id != null && visible != null) {
        list[i] = _copyWithVisible(list[i], visible);
      }
    }
    _emit();
  }

  Calendar _copyWithVisible(Calendar c, bool visible) {
    return Calendar(
      id: c.id,
      remoteId: c.remoteId,
      title: c.title,
      colorArgb: c.colorArgb,
      kind: c.kind,
      groupName: c.groupName,
      isVisible: visible,
      isDefault: c.isDefault,
      sortOrder: c.sortOrder,
      ignoreAlerts: c.ignoreAlerts,
      sourceUrl: c.sourceUrl,
      refreshMinutes: c.refreshMinutes,
      holidayRegion: c.holidayRegion,
      permission: c.permission,
      revision: c.revision,
      deletedAt: c.deletedAt,
    );
  }

  @override
  Stream<List<CalendarEvent>> watchEvents(
      {required DateTime from, required DateTime to, Set<String>? calendarIds}) {
    return Stream.value(const []);
  }

  @override
  Future<CalendarEvent?> getEvent(String id) async => null;

  @override
  Future<void> setDefaultCalendar(String id) async {}

  @override
  Future<void> reorderCalendars(List<String> ids) async {}

  @override
  Future<String> upsertEvent(CalendarEvent e,
      {EditScope scope = EditScope.all, DateTime? occurrenceStart}) async {
    return e.id;
  }

  @override
  Future<void> deleteEvent(String id,
      {EditScope scope = EditScope.all, DateTime? occurrenceStart}) async {}

  @override
  Future<void> moveEvent(String id, String targetCalendarId) async {}

  @override
  Future<List<CalendarEvent>> search(String keyword,
      {DateTime? from, DateTime? to, int limit = 50}) async {
    return const [];
  }

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(CalendarPreference.defaults);

  @override
  Future<void> savePreference(CalendarPreference p) async {}
}
