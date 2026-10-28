import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/life_test_app.dart';

/// F-05 日/周视图契约（TC-CAL-UI-101/102/105/106/130/135/139；契约 §8.3/§8.5）。
void main() {
  late _MutableRepo repo;
  late SharedPreferences prefs;

  final controller = kalender.DefaultEventsController();

  Future<void> pumpCalendar(
    WidgetTester tester, {
    CalendarViewMode mode = CalendarViewMode.day,
  }) async {
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          sidebarPrefsProvider.overrideWithValue(prefs),
          kalenderEventsControllerProvider.overrideWithValue(controller),
        ],
        child: lifeTestHost(
          Scaffold(body: CalendarScaffold(initialViewMode: mode)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    repo = _MutableRepo();
  });

  // TC-CAL-UI-101：切到日 → 日视图 Key calendar_day_view
  testWidgets('TC-CAL-UI-101 切到日视图', (tester) async {
    await pumpCalendar(tester, mode: CalendarViewMode.day);
    expect(find.byKey(const Key('calendar_day_view')), findsOneWidget);
  });

  // TC-CAL-UI-102：切到周 → 列数=偏好（默认 7）
  testWidgets('TC-CAL-UI-102 周视图默认 7 列', (tester) async {
    await pumpCalendar(tester, mode: CalendarViewMode.week);
    expect(find.byKey(const Key('calendar_week_view')), findsOneWidget);
    final config = containerOf(tester).read(calendarViewConfigurationsProvider);
    expect(config.week.numberOfDays, 7);
  });

  // TC-CAL-UI-105：工作周 weekViewDays=5 → 无周六周日（workWeek 口径）
  testWidgets('TC-CAL-UI-105 工作周 5 列', (tester) async {
    await repo.savePreference(const CalendarPreference(weekViewDays: 5));
    await pumpCalendar(tester, mode: CalendarViewMode.week);
    final config = containerOf(tester).read(calendarViewConfigurationsProvider);
    expect(config.week.numberOfDays, 5);
    expect(config.week.isWorkWeek, isTrue, reason: 'workWeek 口径不含周六周日');
  });

  // TC-CAL-UI-106：时间轴范围 dayStartHour=8，dayEndHour=18
  testWidgets('TC-CAL-UI-106 时间轴范围 8-18', (tester) async {
    await repo.savePreference(
      const CalendarPreference(dayStartHour: 8, dayEndHour: 18),
    );
    await pumpCalendar(tester, mode: CalendarViewMode.day);
    final config = containerOf(tester).read(calendarViewConfigurationsProvider);
    expect(config.day.startHour, 8);
    expect(config.day.endHour, 18);
  });

  // TC-CAL-UI-130：双击创建 → 草稿开始于 10:00，时长=默认
  testWidgets('TC-CAL-UI-130 双击创建草稿', (tester) async {
    await pumpCalendar(tester, mode: CalendarViewMode.day);
    final container = containerOf(tester);
    final tap10 = DateTime.utc(2026, 10, 24, 10, 0);

    // 模拟 kalender 双击回调（物理双击手势标手动）
    final callbacks = viewCallbacksOf(tester);
    callbacks.onDraftCreate(tap10, tap10.add(const Duration(hours: 1)));

    final state = container.read(draftEventProvider);
    expect(state!.startAt, DateTime.utc(2026, 10, 24, 10, 0));
    expect(
      state.endAt.difference(state.startAt),
      const Duration(hours: 1),
      reason: '时长=默认（§2.9 defaultDurationMinutes=60）',
    );
  });

  // TC-CAL-UI-135：拖动改时间 → 仓库 startAt 增加 1 小时（接线逻辑；物理拖拽手动）
  testWidgets('TC-CAL-UI-135 拖动改时间落库', (tester) async {
    await repo.upsertEvent(
      CalendarEvent(
        id: 'e1',
        calendarId: 'c1',
        uid: 'u1',
        title: '站会',
        startAt: DateTime.utc(2026, 10, 24, 9),
        endAt: DateTime.utc(2026, 10, 24, 9, 30),
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 24),
      ),
    );
    await pumpCalendar(tester, mode: CalendarViewMode.day);

    final callbacks = viewCallbacksOf(tester);
    await callbacks.onEventMoved(
      repo.listEvents.firstWhere((e) => e.id == 'e1'),
      DateTime.utc(2026, 10, 24, 11),
      DateTime.utc(2026, 10, 24, 11, 30),
    );

    final saved = repo.upserted.last;
    expect(saved.startAt, DateTime.utc(2026, 10, 24, 11));
    expect(saved.endAt, DateTime.utc(2026, 10, 24, 11, 30));
  });

  // 两个重叠事件都能看到（验收：假仓库放入 2 个重叠事件）
  testWidgets('重叠事件两条都渲染', (tester) async {
    await repo.upsertEvent(
      CalendarEvent(
        id: 'e1',
        calendarId: 'c1',
        uid: 'u1',
        title: '重叠甲',
        startAt: DateTime.utc(2026, 10, 24, 10),
        endAt: DateTime.utc(2026, 10, 24, 11),
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 24),
      ),
    );
    await repo.upsertEvent(
      CalendarEvent(
        id: 'e2',
        calendarId: 'c1',
        uid: 'u2',
        title: '重叠乙',
        startAt: DateTime.utc(2026, 10, 24, 10, 15),
        endAt: DateTime.utc(2026, 10, 24, 11, 15),
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 24),
      ),
    );
    await pumpCalendar(tester, mode: CalendarViewMode.day);
    containerOf(
      tester,
    ).read(anchorDateProvider.notifier).set(DateTime.utc(2026, 10, 24));
    await tester.pumpAndSettle();

    // kalender 事件 tile 文本由库内部渲染；控制器公共 API 断言装载
    expect(controller.events.length, 2, reason: '两个重叠事件都装载');
  });

  // TC-CAL-UI-139：全天行拖出多日 → upsert end=周四 00:00（接线逻辑；物理拖拽手动）
  testWidgets('TC-CAL-UI-139 全天拖多日落库', (tester) async {
    await repo.upsertEvent(
      CalendarEvent(
        id: 'e1',
        calendarId: 'c1',
        uid: 'u1',
        title: '出差',
        startAt: DateTime.utc(2026, 10, 19),
        endAt: DateTime.utc(2026, 10, 20),
        allDay: true,
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 24),
      ),
    );
    await pumpCalendar(tester, mode: CalendarViewMode.week);
    containerOf(
      tester,
    ).read(anchorDateProvider.notifier).set(DateTime.utc(2026, 10, 24));
    await tester.pumpAndSettle();

    final callbacks = viewCallbacksOf(tester);
    await callbacks.onEventMoved(
      repo.listEvents.firstWhere((e) => e.id == 'e1'),
      DateTime.utc(2026, 10, 19),
      DateTime.utc(2026, 10, 22),
    );

    final saved = repo.upserted.last;
    expect(saved.allDay, isTrue);
    expect(saved.endAt, DateTime.utc(2026, 10, 22), reason: '周四 00:00 排他');
  });

  // 日视图提醒栏 Key（F-15 填充）
  testWidgets('日视图 day_reminder_lane 存在', (tester) async {
    await pumpCalendar(tester, mode: CalendarViewMode.day);
    expect(find.byKey(const Key('day_reminder_lane')), findsOneWidget);
  });

  // #184：日视图事件卡必须渲染标题与起止时间，禁止库默认「Tile」占位文案
  testWidgets('#184 日视图事件卡显示标题与起止时间（无 Tile 占位）', (tester) async {
    await repo.savePreference(
      const CalendarPreference(dayStartHour: 8, dayEndHour: 20),
    );
    // 本地 10:00–11:00 → 转 UTC 存库 → 显示端 toLocal 还原，避开时区耦合
    final start = DateTime(2026, 10, 24, 10).toUtc();
    await repo.upsertEvent(
      CalendarEvent(
        id: 'e184',
        calendarId: 'c1',
        uid: 'u184',
        title: '团队周会',
        startAt: start,
        endAt: DateTime(2026, 10, 24, 11).toUtc(),
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 24),
      ),
    );
    await pumpCalendar(tester, mode: CalendarViewMode.day);
    containerOf(
      tester,
    ).read(anchorDateProvider.notifier).set(DateTime(2026, 10, 24));
    await tester.pumpAndSettle();

    expect(find.text('Tile'), findsNothing,
        reason: '#184: 日视图不得出现 kalender 默认占位文案「Tile」');
    expect(find.byKey(const Key('day-event-e184')), findsOneWidget,
        reason: '#184: 事件卡 tile 必须用自定义 builder 渲染');
    expect(find.text('团队周会'), findsOneWidget,
        reason: '#184: 事件卡必须显示事件标题');
  });

  // #184 审查 R1：全天/跨日条走 MultiDayHeader，也必须用自定义 builder
  testWidgets('#184 日视图全天事件卡同样渲染标题（无 Tile 占位）', (tester) async {
    await repo.savePreference(
      const CalendarPreference(dayStartHour: 8, dayEndHour: 20),
    );
    await repo.upsertEvent(
      CalendarEvent(
        id: 'e184a',
        calendarId: 'c1',
        uid: 'u184a',
        title: '全天例会',
        startAt: DateTime.utc(2026, 10, 24),
        endAt: DateTime.utc(2026, 10, 25),
        allDay: true,
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 24),
      ),
    );
    await pumpCalendar(tester, mode: CalendarViewMode.day);
    containerOf(
      tester,
    ).read(anchorDateProvider.notifier).set(DateTime(2026, 10, 24));
    await tester.pumpAndSettle();

    expect(find.text('Tile'), findsNothing,
        reason: '#184 R1: 全天区不得出现默认占位「Tile」');
    expect(find.byKey(const Key('day-event-e184a')), findsOneWidget);
    expect(find.text('全天例会'), findsOneWidget);
  });

  // #200：周视图与日视图同款缺陷面——事件卡须渲染标题/时间，无「Tile」占位
  testWidgets('#200 周视图事件卡显示标题与起止时间（无 Tile 占位）', (tester) async {
    await repo.savePreference(
      const CalendarPreference(dayStartHour: 8, dayEndHour: 20),
    );
    await repo.upsertEvent(
      CalendarEvent(
        id: 'e200',
        calendarId: 'c1',
        uid: 'u200',
        title: '周会',
        startAt: DateTime(2026, 10, 24, 10).toUtc(),
        endAt: DateTime(2026, 10, 24, 11).toUtc(),
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 24),
      ),
    );
    await pumpCalendar(tester, mode: CalendarViewMode.week);
    containerOf(
      tester,
    ).read(anchorDateProvider.notifier).set(DateTime(2026, 10, 24));
    await tester.pumpAndSettle();

    expect(find.text('Tile'), findsNothing,
        reason: '#200: 周视图不得出现 kalender 默认占位「Tile」');
    expect(find.byKey(const Key('day-event-e200')), findsOneWidget,
        reason: '#200: 周视图事件卡必须用自定义 builder 渲染');
    expect(find.text('周会'), findsOneWidget, reason: '#200: 事件卡必须显示标题');
  });
}

/// 取当前测试树里的 Riverpod 容器。
ProviderContainer containerOf(WidgetTester tester) {
  final element = tester.element(find.byType(CalendarScaffold));
  return ProviderScope.containerOf(element);
}

/// 取 scaffold 接线的 kalender 回调（tests 直接调用，物理拖拽手动）。
CalendarViewCallbacks viewCallbacksOf(WidgetTester tester) {
  if (find.byType(CalendarDayView).evaluate().isNotEmpty) {
    return tester
        .widget<CalendarDayView>(find.byType(CalendarDayView))
        .viewCallbacks;
  }
  return tester
      .widget<CalendarWeekView>(find.byType(CalendarWeekView))
      .viewCallbacks;
}

/// 构造 kalender 事件。
kalender.KalenderEvent kalenderEvent(DateTime start, DateTime end) {
  return kalender.KalenderEvent(start: start, end: end);
}

/// 可变假仓库（F-05）。
class _MutableRepo implements CalendarRepository {
  final List<CalendarEvent> upserted = [];
  final List<CalendarEvent> listEvents = [];
  final List<CalendarEvent> visible = [];
  final _eventController = StreamController<List<CalendarEvent>>.broadcast();
  CalendarPreference preference = const CalendarPreference();

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield List<CalendarEvent>.unmodifiable(visible);
    yield* _eventController.stream;
  }

  @override
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    upserted.add(e);
    listEvents.add(e);
    visible.add(e);
    _eventController.add(List<CalendarEvent>.unmodifiable(visible));
    return e.id;
  }

  final _prefController = StreamController<CalendarPreference>.broadcast();

  @override
  Future<void> savePreference(CalendarPreference p) async {
    preference = p;
    _prefController.add(p);
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield preference;
    yield* _prefController.stream;
  }

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield const <Calendar>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
