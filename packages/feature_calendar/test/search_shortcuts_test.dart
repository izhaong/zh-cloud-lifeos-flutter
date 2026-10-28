import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'support/life_test_app.dart';

/// F-13 搜索与快捷键（TC-CAL-UI-171/501/502；契约 §8.4）。
void main() {
  CalendarEvent event(
    String id,
    String title, {
    String? location,
    String? notes,
  }) => CalendarEvent(
    id: id,
    calendarId: 'c1',
    uid: id,
    title: title,
    location: location,
    notes: notes,
    startAt: DateTime.utc(2026, 10, 24, 2),
    endAt: DateTime.utc(2026, 10, 24, 3),
    timeZone: 'UTC',
    updatedAt: DateTime.utc(2026, 10, 24),
  );

  group('搜索', () {
    test('TC-CAL-UI-171 标题/地点/备注三路命中', () {
      expect(matchesCalendarSearch(event('e1', '牙医'), '牙医'), isTrue);
      expect(
        matchesCalendarSearch(event('e2', '周会', location: '牙医诊所'), '牙医'),
        isTrue,
      );
      expect(
        matchesCalendarSearch(event('e3', '复盘', notes: '带牙医报告'), '牙医'),
        isTrue,
      );
      expect(matchesCalendarSearch(event('e1', '牙医'), ''), isTrue);
      expect(matchesCalendarSearch(event('e1', '牙医'), '长跑'), isFalse);
    });

    testWidgets('TC-CAL-UI-171 月视图只剩命中项，清空恢复', (tester) async {
      final repo = _Repo()
        ..events.addAll([
          event('e1', '牙医'),
          event('e2', '周会', location: '牙科室'),
        ]);
      final controller = kalender.DefaultEventsController();
      final container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          sidebarPrefsProvider.overrideWith((ref) => null),
          kalenderEventsControllerProvider.overrideWithValue(controller),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(anchorDateProvider.notifier)
          .set(DateTime.utc(2026, 10, 24));
      container.read(searchQueryProvider.notifier).set('牙医');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(
            Scaffold(
              body: CalendarMonthView(
                viewCallbacks: CalendarViewCallbacks(
                  repo: repo,
                  preference: const CalendarPreference(),
                  setDraft: (_) {},
                ),
                eventsController: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('牙医'), findsOneWidget);
      expect(find.text('周会'), findsNothing, reason: '标题不含关键词');

      container.read(searchQueryProvider.notifier).set('');
      await tester.pumpAndSettle();
      expect(find.text('周会'), findsOneWidget, reason: '清空后恢复');
    });

    testWidgets('工具栏搜索框写入 query', (tester) async {
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(const Scaffold(body: CalendarToolbar())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calendar_search_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calendar_search_field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('calendar_search_field')),
        '牙医',
      );
      await tester.pump();
      expect(container.read(searchQueryProvider), '牙医');

      await tester.tap(find.byKey(const Key('calendar_search_close')));
      await tester.pumpAndSettle();
      expect(container.read(searchQueryProvider), '');
      expect(container.read(searchActiveProvider), isFalse);
    });
  });

  group('快捷键', () {
    // #310：绑定表断言从「13 条 containsKey」升级为「逐条对 Intent + 载荷 + 裸键分离」，
    // 并把一度散在独立文件 calendar_shortcuts_test.dart 的等价断言收回本文件（F-13 的家）。
    final mod = calendarShortcutBindings();
    final bare = calendarUnmodifiedShortcutBindings();
    final sidebar = sidebarShortcutBindings();

  test('修饰键表：逐条断言契约 §8.4 的键位绑到预期 Intent', () {
    expect(mod.length, 21, reason: '绑定数量变化必须同步改本测试与契约 §8.4');

    final expected = <ShortcutActivator, Type>{
      const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
          NextPeriodIntent,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
          PrevPeriodIntent,
      const SingleActivator(LogicalKeyboardKey.keyT, meta: true): TodayIntent,
      const SingleActivator(LogicalKeyboardKey.keyT, meta: true, shift: true):
          JumpToDateIntent,
      const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
          SetViewModeIntent,
      const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
          SetViewModeIntent,
      const SingleActivator(LogicalKeyboardKey.digit3, meta: true):
          SetViewModeIntent,
      const SingleActivator(LogicalKeyboardKey.digit4, meta: true):
          SetViewModeIntent,
      const SingleActivator(LogicalKeyboardKey.keyR, meta: true): RefreshIntent,
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
          NewEventIntent,
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
          EditSelectedIntent,
      const SingleActivator(LogicalKeyboardKey.keyI, meta: true, alt: true):
          OpenInspectorWindowIntent,
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
          FocusSearchIntent,
      const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
          ShowInfoIntent,
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
          NewCalendarGroupIntent,
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true, alt: true):
          NewSubscriptionIntent,
      const SingleActivator(LogicalKeyboardKey.arrowUp,
          control: true, alt: true): MoveSelectionIntent,
      const SingleActivator(LogicalKeyboardKey.arrowDown,
          control: true, alt: true): MoveSelectionIntent,
      const SingleActivator(LogicalKeyboardKey.arrowRight,
          control: true, alt: true): MoveSelectionIntent,
      const SingleActivator(LogicalKeyboardKey.arrowLeft,
          control: true, alt: true): MoveSelectionIntent,
      const SingleActivator(LogicalKeyboardKey.comma, meta: true):
          OpenSettingsIntent,
    };

    for (final e in expected.entries) {
      expect(mod.containsKey(e.key), isTrue, reason: '缺少绑定：${e.key}');
      expect(
        mod[e.key].runtimeType,
        e.value,
        reason: '$e.key 应绑到 ${e.value}',
      );
    }
    expect(mod.length, expected.length, reason: '不得有契约外的多余绑定');
  });

  test('⌘1~4 分别切日/周/月/年（同一 Intent、不同载荷）', () {
    final modes = <int, CalendarViewMode>{
      LogicalKeyboardKey.digit1.keyId: CalendarViewMode.day,
      LogicalKeyboardKey.digit2.keyId: CalendarViewMode.week,
      LogicalKeyboardKey.digit3.keyId: CalendarViewMode.month,
      LogicalKeyboardKey.digit4.keyId: CalendarViewMode.year,
    };
    for (final activator in mod.keys.whereType<SingleActivator>()) {
      final mode = modes[activator.trigger.keyId];
      if (mode == null) continue;
      expect((mod[activator]! as SetViewModeIntent).mode, mode,
          reason: '${activator.trigger.keyLabel} 应切到 $mode');
    }
  });

  test('⌃⌥方向键的移动量：↑+15 分 / ↓-15 分 / →+1 天 / ←-1 天', () {
    final expected = <LogicalKeyboardKey, Duration>{
      LogicalKeyboardKey.arrowUp: const Duration(minutes: 15),
      LogicalKeyboardKey.arrowDown: const Duration(minutes: -15),
      LogicalKeyboardKey.arrowRight: const Duration(days: 1),
      LogicalKeyboardKey.arrowLeft: const Duration(days: -1),
    };
    var checked = 0;
    for (final activator in mod.keys.whereType<SingleActivator>()) {
      // 必须同时是 ⌃⌥：只看 trigger 会把 ⌘→（NextPeriod）也算进来
      if (!activator.control || !activator.alt) continue;
      final delta = expected[activator.trigger];
      if (delta == null) continue;
      expect((mod[activator]! as MoveSelectionIntent).delta, delta);
      checked++;
    }
    expect(checked, 4, reason: '四个 ⌃⌥ 方向键都要在表里');
  });

  test('裸键（Delete/Esc/Return）只挂在独立表里，不进全局表', () {
    expect(bare.length, 3);
    expect(
      bare[const SingleActivator(LogicalKeyboardKey.delete)].runtimeType,
      DeleteSelectedIntent,
    );
    expect(
      bare[const SingleActivator(LogicalKeyboardKey.escape)].runtimeType,
      CloseEditingIntent,
    );
    expect(
      bare[const SingleActivator(LogicalKeyboardKey.enter)].runtimeType,
      CloseEditingIntent,
    );
    // 全局表里不得出现裸键（否则会吞掉文本框输入）
    for (final activator in mod.keys.whereType<SingleActivator>()) {
      expect(
        activator.meta || activator.control || activator.alt,
        isTrue,
        reason: '${activator.trigger.keyLabel} 没有修饰键，不该在全局表里',
      );
    }
  });

  test('侧栏 Space 切显隐（仅侧栏焦点内）', () {
    expect(sidebar.length, 1);
    expect(
      sidebar[const SingleActivator(LogicalKeyboardKey.space)].runtimeType,
      ToggleCalendarVisibilityIntent,
    );
  });

    testWidgets('TC-CAL-UI-502 NewEventIntent 触发快速事件', (tester) async {
      var opened = 0;
      late BuildContext innerContext;
      await tester.pumpWidget(
        lifeTestHost(
          CalendarShortcutActions(
            onNewEvent: () => opened++,
            child: Builder(
              builder: (context) {
                innerContext = context;
                return const Scaffold(body: Text('body'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Actions.invoke(innerContext, const NewEventIntent());
      await tester.pump();
      expect(opened, 1);
    });
  });
}

class _Repo implements CalendarRepository {
  final List<CalendarEvent> events = [];
  final List<Calendar> calendars = const [
    Calendar(id: 'c1', title: '工作', colorArgb: 0xFF007AFF),
  ];
  final _events = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield List<CalendarEvent>.unmodifiable(events);
    yield* _events.stream;
  }

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield calendars;
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
    yield* const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
