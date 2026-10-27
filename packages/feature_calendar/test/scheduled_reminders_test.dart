import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'support/life_test_app.dart';

/// F-15 提醒事项投影（TC-CAL-KR-401～405、UI-190～194；契约 §5.2）。
void main() {
  const red = 0xFFFF3B30;
  final lists = [const ReminderList(id: 'l1', title: '提醒', colorArgb: red)];

  ReminderItem item({
    String id = 'r1',
    DateTime? dueAt,
    bool completed = false,
    String? recurrence,
  }) => ReminderItem(
    id: id,
    listId: 'l1',
    title: '取快递',
    dueAt: dueAt,
    isCompleted: completed,
    recurrence: recurrence,
  );

  final from = DateTime.utc(2026, 10, 24);
  final to = DateTime.utc(2026, 10, 25);

  group('投影纯函数', () {
    test('TC-CAL-KR-401 定时提醒 → reminder occurrence + 列表色', () {
      final result = projectScheduledReminders(
        [item(dueAt: DateTime.utc(2026, 10, 24, 10))],
        lists,
        from: from,
        to: to,
      );
      final o = result.single;
      expect(o.source, OccurrenceSource.reminder);
      expect(o.start, DateTime.utc(2026, 10, 24, 10));
      expect(o.colorArgb, red);
      expect(o.allDay, isFalse);
      expect(o.reminderId, 'r1');
    });

    test('TC-CAL-KR-402 当天 00:00 → 全天', () {
      final result = projectScheduledReminders(
        [item(dueAt: DateTime.utc(2026, 10, 24))],
        lists,
        from: from,
        to: to,
      );
      expect(result.single.allDay, isTrue);
      expect(result.single.end, DateTime.utc(2026, 10, 25));
    });

    test('TC-CAL-KR-403 dueAt=null 不投影', () {
      expect(
        projectScheduledReminders([item()], lists, from: from, to: to),
        isEmpty,
      );
    });

    test('TC-CAL-KR-404 已完成带 completed=true', () {
      final result = projectScheduledReminders(
        [item(dueAt: DateTime.utc(2026, 10, 24, 10), completed: true)],
        lists,
        from: from,
        to: to,
      );
      expect(result.single.completed, isTrue);
    });

    test('TC-CAL-KR-405 重复提醒只显示未完成的下一次', () {
      final result = projectScheduledReminders(
        [
          item(
            dueAt: DateTime.utc(2026, 10, 24, 10),
            completed: true,
            recurrence: 'daily',
          ),
        ],
        lists,
        from: from,
        to: to,
      );
      expect(result, isEmpty);
    });
  });

  group('投影接线', () {
    testWidgets('TC-CAL-UI-190/194 月视图渲染提醒（红色由投影断言）', (tester) async {
      final reminderRepo = _ReminderRepo()
        ..lists.addAll(lists)
        ..items.add(item(dueAt: DateTime.utc(2026, 10, 24, 10)));
      final controller = kalender.DefaultEventsController();
      final container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(_CalendarRepo()),
          calendarReminderRepositoryProvider.overrideWithValue(reminderRepo),
          sidebarPrefsProvider.overrideWith((ref) => null),
          kalenderEventsControllerProvider.overrideWithValue(controller),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(anchorDateProvider.notifier)
          .set(DateTime.utc(2026, 10, 24));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(
            Scaffold(
              body: CalendarMonthView(
                viewCallbacks: CalendarViewCallbacks(
                  repo: _CalendarRepo(),
                  preference: const CalendarPreference(),
                  setDraft: (_) {},
                  reminderRepository: reminderRepo,
                ),
                eventsController: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('取快递'), findsOneWidget, reason: 'TC-CAL-UI-190 提醒进入月视图');
    });

    test('TC-CAL-UI-192 点进行切换完成', () async {
      final reminderRepo = _ReminderRepo();
      final callbacks = CalendarViewCallbacks(
        repo: _CalendarRepo(),
        preference: const CalendarPreference(),
        setDraft: (_) {},
        reminderRepository: reminderRepo,
      );
      final occurrence = projectScheduledReminders(
        [item(dueAt: DateTime.utc(2026, 10, 24, 10))],
        lists,
        from: from,
        to: to,
      ).single;

      await callbacks.onOccurrenceTapped(occurrence);
      expect(reminderRepo.toggled, ['r1']);
    });

    test('TC-CAL-UI-193 删除走提醒事项', () async {
      final reminderRepo = _ReminderRepo();
      final callbacks = CalendarViewCallbacks(
        repo: _CalendarRepo(),
        preference: const CalendarPreference(),
        setDraft: (_) {},
        reminderRepository: reminderRepo,
      );
      final occurrence = projectScheduledReminders(
        [item(dueAt: DateTime.utc(2026, 10, 24, 10))],
        lists,
        from: from,
        to: to,
      ).single;

      await callbacks.deleteReminderOccurrence(occurrence);
      expect(reminderRepo.deleted, ['r1']);
      expect(reminderRepo.upserted, isEmpty, reason: '不走日历事件写入');
    });

    testWidgets('TC-CAL-UI-191 ＋ → 新建提醒写入 ReminderRepository', (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final reminderRepo = _ReminderRepo()..lists.addAll(lists);
      final controller = kalender.DefaultEventsController();
      final container = ProviderContainer(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(_CalendarRepo()),
          calendarReminderRepositoryProvider.overrideWithValue(reminderRepo),
          sidebarPrefsProvider.overrideWith((ref) => null),
          kalenderEventsControllerProvider.overrideWithValue(controller),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: lifeTestHost(const CalendarScaffold()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_create_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_create_reminder')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('quick_event_input')), '取快递');
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick_event_create')));
      await tester.pumpAndSettle();

      expect(reminderRepo.upserted.single.title, '取快递');
      expect(reminderRepo.upserted.single.listId, 'l1');
    });
  });
}

class _CalendarRepo implements CalendarRepository {
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
    yield const <CalendarEvent>[];
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

class _ReminderRepo implements ReminderRepository {
  final List<ReminderList> lists = [];
  final List<ReminderItem> items = [];
  final List<String> toggled = [];
  final List<String> deleted = [];
  final List<ReminderItem> upserted = [];
  final _items = StreamController<List<ReminderItem>>.broadcast();
  final _lists = StreamController<List<ReminderList>>.broadcast();

  @override
  Stream<List<ReminderItem>> watchItems({String? listId}) async* {
    yield List<ReminderItem>.unmodifiable(items);
    yield* _items.stream;
  }

  @override
  Stream<List<ReminderList>> watchLists() async* {
    yield List<ReminderList>.unmodifiable(lists);
    yield* _lists.stream;
  }

  @override
  Future<void> toggleCompleted(String itemId) async {
    toggled.add(itemId);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    deleted.add(itemId);
  }

  @override
  Future<void> upsertItem(ReminderItem item) async {
    upserted.add(item);
    items.add(item);
    _items.add(List<ReminderItem>.unmodifiable(items));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
