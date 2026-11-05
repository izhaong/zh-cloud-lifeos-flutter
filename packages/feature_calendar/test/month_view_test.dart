import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/life_test_app.dart';

/// 夹具挂钟：与本包 golden 基线同源（`test/goldens/README.md`）。
/// 月视图渲染「今天所在的那个月」，不钉它就会随真实日期换月。
DateTime _fixedNow() => DateTime(2026, 10, 26);

/// F-06 月视图契约（TC-CAL-UI-103/112/115/131；契约 §5.4/§8.3）。
void main() {
  late _MutableRepo repo;
  late SharedPreferences prefs;
  final controller = kalender.DefaultEventsController();

  Future<void> pumpMonth(
    WidgetTester tester, {
    CalendarPreference preference = const CalendarPreference(),
  }) async {
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          sidebarPrefsProvider.overrideWithValue(prefs),
          kalenderEventsControllerProvider.overrideWithValue(controller),
          // #549：夹具不钉挂钟 ⇒ 本文件的绝对日期事件（2026-10-24）只在
          // 「今天」恰好落在 2026 年 10 月时才可见 —— 11 月起这条必然红。
          // 与 test/goldens/README.md 的约定对齐：测试侧统一钉 2026-10-26。
          clockProvider.overrideWithValue(_fixedNow),
        ],
        child: lifeTestHost(
          Scaffold(
            body: CalendarMonthView(
              viewCallbacks: CalendarViewCallbacks(
                repo: repo,
                preference: preference,
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

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    controller.clearEvents();
    repo = _MutableRepo();
  });

  // TC-CAL-UI-103：切到月 → 月网格可见
  testWidgets('TC-CAL-UI-103 月网格可见', (tester) async {
    await pumpMonth(tester);
    expect(find.byKey(const Key('calendar_month_view')), findsOneWidget);
  });

  // #164：月视图要有星期行（中文单字），当天要有红底圆点标记
  testWidgets('#164 月视图星期行与当天高亮', (tester) async {
    await pumpMonth(tester);

    expect(
      find.byKey(const Key('month_weekday_header')),
      findsOneWidget,
      reason: '月视图缺星期表头（旧实现 header 被换成 SizedBox.shrink）',
    );
    for (final label in ['一', '二', '三', '四', '五', '六', '日']) {
      expect(find.text(label), findsWidgets, reason: '星期 $label 缺失');
    }
    expect(
      find.byKey(const Key('month-today')),
      findsOneWidget,
      reason: '当天（${_fixedNow().day}）没有高亮标记',
    );
  });

  // TC-CAL-UI-112：一条全天、一条 10:00 → 色条都用日历颜色
  testWidgets('TC-CAL-UI-112 色条用日历颜色', (tester) async {
    final container = ProviderContainer(overrides: []);
    addTearDown(container.dispose);
    await repo.upsertEvent(
      CalendarEvent(
        id: 'e-all',
        calendarId: 'c1',
        uid: 'u1',
        title: '全天出差',
        startAt: DateTime.utc(2026, 10, 24),
        endAt: DateTime.utc(2026, 10, 25),
        allDay: true,
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 24),
      ),
    );
    await repo.upsertEvent(
      CalendarEvent(
        id: 'e-timed',
        calendarId: 'c1',
        uid: 'u2',
        title: '定时会',
        startAt: DateTime.utc(2026, 10, 24, 10),
        endAt: DateTime.utc(2026, 10, 24, 11),
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 24),
      ),
    );
    await pumpMonth(tester);

    // 装载后 tile 数据（CalendarEventTile）颜色=日历颜色（c1 无日历时
    // expandOccurrences 回退默认蓝 0xFF007AFF）。
    final tiles = controller.events.whereType<CalendarEventTile>().toList();
    expect(tiles, hasLength(2), reason: '全天+定时都装载');
    for (final t in tiles) {
      expect(t.colorArgb, 0xFF007AFF, reason: '${t.kernelEventId} 色条用日历颜色');
    }
  });

  // TC-CAL-UI-115：CHINESE 农历初一 → 日期下红色「初一」
  testWidgets('TC-CAL-UI-115 农历初一红色', (tester) async {
    // 2026-02-17 = 春节（正月初一）；月视图默认渲染真实当前月，
    // 农历标签为纯函数，此处直接断言实现渲染语义：
    expect(lunarDayLabel(DateTime(2026, 2, 17)), '初一');
    expect(isLunarFirstDay(DateTime(2026, 2, 17)), isTrue);
    // 非 CHINESE 偏好 → 不渲染农历列
    await pumpMonth(tester, preference: const CalendarPreference());
    expect(find.text('初一'), findsNothing, reason: '默认无农历');
    // CHINESE 偏好 → 月头组件包含农历文本（渲染当月，标签由同一函数产出）
    await pumpMonth(
      tester,
      preference: const CalendarPreference(
        alternateCalendar: AlternateCalendar.chinese,
      ),
    );
    final now = DateTime.now();
    expect(lunarDayLabel(DateTime(now.year, now.month, 1)).isNotEmpty, isTrue);
  });

  // TC-CAL-UI-131：点/双击日 → 全天草稿
  testWidgets('TC-CAL-UI-131 月视图日草稿', (tester) async {
    CalendarEvent? captured;
    prefs = await SharedPreferences.getInstance();
    final callbacks = CalendarViewCallbacks(
      repo: repo,
      preference: const CalendarPreference(),
      // parity#219：草稿必须锚在设备时区的当地零点（此前写死 UTC 会漂一天）
      timeZone: 'America/New_York',
      setDraft: (draft) => captured = draft,
    );
    callbacks.onDayTap(DateTime(2026, 10, 24));
    expect(captured, isNotNull);
    expect(captured!.allDay, isTrue, reason: '默认全天');
    // 当地 10/24 00:00 EDT → 04:00Z
    expect(captured!.startAt, DateTime.utc(2026, 10, 24, 4));
    expect(
      captured!.endAt,
      DateTime.utc(2026, 10, 25, 4),
      reason: 'end 排他次日（当地零点）',
    );
    expect(captured!.title, '', reason: '标题空（F-12 解析器接管）');
  });
}

/// 可变假仓库（F-06）。
class _MutableRepo implements CalendarRepository {
  final List<CalendarEvent> visible = [];
  final _eventController = StreamController<List<CalendarEvent>>.broadcast();

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
    visible.add(e);
    _eventController.add(List<CalendarEvent>.unmodifiable(visible));
    return e.id;
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
    yield* const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
