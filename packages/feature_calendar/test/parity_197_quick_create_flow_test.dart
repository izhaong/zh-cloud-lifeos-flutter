import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/life_test_app.dart';

/// parity#197 复现：expanded（1600）全流程
/// ＋ → 新建日程 → 输入标题 → 创建 → Inspector 第三栏 → 保存 → 落库 + 视图渲染。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('#197 快捷创建全流程：创建→Inspector→保存→日视图可见', (tester) async {
    final repo = _Repo();
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(const CalendarTabEntry()),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 工具栏「＋」→「新建日程」
    await tester.tap(find.byKey(const Key('quick_create_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_create_event')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_event_dialog')), findsOneWidget);

    // 2. 输入标题（无时间词 → 解析为全天/仅日期），点「创建」
    await tester.enterText(find.byKey(const Key('quick_event_input')), '团队周会');
    await tester.pump();
    // 无时间词 → 解析为全天事件（标题 · 日期），保存后落在全天区
    expect(
      tester.widget<Text>(find.byKey(const Key('quick_event_preview'))).data,
      contains('团队周会'),
    );

    await tester.tap(find.byKey(const Key('quick_event_create')));
    await tester.pumpAndSettle();

    // 3. 创建后：expanded 第三栏 Inspector 应出现（草稿态，未落库）
    expect(find.byKey(const Key('event_inspector_pane')), findsOneWidget,
        reason: '#197: 创建后第三栏 Inspector 必须出现（expanded 档）');
    expect(repo.upserted, isEmpty, reason: '#197: 创建仅进草稿，尚未落库（设计=保存时落库）');

    // 4. 点「保存」→ 落库
    await tester.tap(find.byKey(const Key('event_inspector_save')));
    await tester.pumpAndSettle();

    expect(repo.upserted, isNotEmpty, reason: '#197: 保存必须落库');
    expect(repo.upserted.last.title, '团队周会');
    expect(repo.upserted.last.calendarId, isNotEmpty,
        reason: '#197: 空 calendarId 草稿保存时必须回写默认日历');

    // 5. 日视图渲染事件（timed=body tile / allDay=header tile，均含标题文本）
    expect(find.text('团队周会'), findsOneWidget,
        reason: '#197: 保存后日视图必须出现该事件（全天区或时间轴）');
  });

  // #197 审查 R1（#407 起阈值 1200→1000）：壳层左轨挤占内容宽（MediaQuery 1600 但
  // LayoutBuilder 900）→ 仍走 medium sheet，不允许草稿悬空。
  testWidgets('#197 内容宽<1000（壳层左轨）创建走 sheet 编辑面', (tester) async {
    final repo = _Repo();
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(
          // 模拟壳层左轨：内容区被压缩到 900，MediaQuery 仍是 1600
          const Center(
            child: SizedBox(
              width: 900,
              height: 900,
              child: CalendarTabEntry(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick_create_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_create_event')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quick_event_input')), '团队周会');
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick_event_create')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('event_inspector_pane')), findsOneWidget,
        reason: '#197 R1: 内容宽<1000 时创建必须落到 sheet 编辑面，草稿不得悬空');
    expect(find.byKey(const Key('event_inspector_sheet')), findsOneWidget,
        reason: '#407: 内容宽<1000 时应是 sheet 形态');
    expect(repo.upserted, isEmpty);
  });

  // #407：内容宽 1000–1199（约 1240–1440 窗宽）按 Apple 直接出右侧第三栏。
  testWidgets('#407 内容宽 1100 创建走右侧 Inspector 第三栏', (tester) async {
    final repo = _Repo();
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(
          const Center(
            child: SizedBox(
              width: 1100,
              height: 900,
              child: CalendarTabEntry(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick_create_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_create_event')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quick_event_input')), '团队周会');
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick_event_create')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('event_inspector_pane')), findsOneWidget,
        reason: '#407: 内容宽 1100 应直接在第三栏出 Inspector');
    expect(find.byKey(const Key('event_inspector_sheet')), findsNothing,
        reason: '#407: 内容宽 ≥1000 不应再弹 sheet');
    expect(repo.upserted, isEmpty);
  });
}

class _Repo implements CalendarRepository {
  final List<CalendarEvent> visible = [];
  final List<CalendarEvent> upserted = [];
  final _events = StreamController<List<CalendarEvent>>.broadcast();
  final _cals = StreamController<List<Calendar>>.broadcast();
  CalendarPreference preference = const CalendarPreference();
  final _prefs = StreamController<CalendarPreference>.broadcast();

  _Repo() {
    _cals.add(const [
      Calendar(
        id: 'c1',
        title: '日历',
        colorArgb: 0xFF007AFF,
        isDefault: true,
      ),
    ]);
  }

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield const [
      Calendar(id: 'c1', title: '日历', colorArgb: 0xFF007AFF, isDefault: true),
    ];
    yield* _cals.stream;
  }

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield List<CalendarEvent>.unmodifiable(visible);
    yield* _events.stream;
  }

  @override
  Future<CalendarEvent?> getEvent(String id) async =>
      visible.where((e) => e.id == id).firstOrNull;

  @override
  Future<void> upsertCalendar(Calendar c) async {}

  @override
  Future<void> deleteCalendar(String id) async {}

  @override
  Future<void> setDefaultCalendar(String id) async {}

  @override
  Future<void> reorderCalendars(List<String> ids) async {}

  @override
  Future<void> setVisibility({
    String? id,
    bool? visible,
    bool? allVisible,
    String? onlyId,
  }) async {}

  @override
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    upserted.add(e);
    visible.add(e);
    _events.add(List<CalendarEvent>.unmodifiable(visible));
    return e.id;
  }

  @override
  Future<void> deleteEvent(
    String id, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {}

  @override
  Future<void> moveEvent(String id, String targetCalendarId) async {}

  @override
  Future<List<CalendarEvent>> search(
    String keyword, {
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) async =>
      const [];

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield preference;
    yield* _prefs.stream;
  }

  @override
  Future<void> savePreference(CalendarPreference p) async {
    preference = p;
    _prefs.add(p);
  }
}
