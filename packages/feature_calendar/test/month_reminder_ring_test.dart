// TC-CAL-UI-194（#402）：月视图里「提醒事项」与「日程」必须一眼可分。
//
// Apple 口径：日程是实心色条，提醒是**空心圆 + 文字**。此前两者走同一个 tile
// 渲染，只剩右键菜单的差别（用户看不见）。
import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements CalendarRepository {
  _Repo({required this.events, required this.reminders});

  final List<CalendarEvent> events;
  final List<ReminderItem> reminders;
  final List<Calendar> calendars = const [
    Calendar(id: 'c1', title: '工作', colorArgb: 0xFF007AFF),
  ];

  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(calendars);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) =>
      Stream.value(events);

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(const CalendarPreference());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReminderRepo implements ReminderRepository {
  _ReminderRepo({required this.items, required this.lists});

  final List<ReminderItem> items;
  final List<ReminderList> lists;

  @override
  Stream<List<ReminderItem>> watchItems({
    String? listId,
    bool includeCompleted = false,
  }) =>
      Stream.value(items);

  @override
  Stream<List<ReminderList>> watchLists() => Stream.value(lists);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CalendarEvent _event(String id, String title, DateTime start) => CalendarEvent(
      id: id,
      calendarId: 'c1',
      uid: id,
      title: title,
      startAt: start,
      endAt: start.add(const Duration(hours: 1)),
      timeZone: 'Asia/Shanghai',
      updatedAt: DateTime(2026, 10, 1),
    );

Future<void> _pump(WidgetTester tester, _Repo repo, _ReminderRepo reminders) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});

  final container = ProviderContainer(overrides: [
    calendarRepositoryProvider.overrideWithValue(repo),
    calendarReminderRepositoryProvider.overrideWithValue(reminders),
    scheduledRemindersVisibleProvider.overrideWith(() => _VisibleTrue()),
    sidebarPrefsProvider.overrideWith((ref) => null),
    clockProvider.overrideWithValue(() => DateTime(2026, 10, 29, 9)),
    kalenderEventsControllerProvider
        .overrideWithValue(kalender.DefaultEventsController()),
  ]);
  addTearDown(container.dispose);
  container.read(anchorDateProvider.notifier).set(DateTime(2026, 10, 29));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: CalendarScaffold(initialViewMode: CalendarViewMode.month),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _VisibleTrue extends ScheduledRemindersVisibleNotifier {
  @override
  bool build() => true;
}

void main() {
  testWidgets('#402 提醒在月视图渲染为空心圆（不是事件色条）', (tester) async {
    final day = DateTime(2026, 10, 29, 10);
    final repo = _Repo(
      events: [_event('e1', '周会', day)],
      reminders: [
        ReminderItem(
          id: 'r1',
          listId: 'l1',
          title: '买牛奶',
          dueAt: day,
        ),
      ],
    );
    final reminders = _ReminderRepo(
      items: repo.reminders,
      lists: const [ReminderList(id: 'l1', title: '个人')],
    );

    await _pump(tester, repo, reminders);

    expect(find.byKey(const Key('month-reminder-r1')), findsOneWidget,
        reason: '提醒要以提醒专用 tile 渲染');
    expect(find.byKey(const Key('month-event-e1')), findsOneWidget,
        reason: '普通日程仍是日程 tile');
  });
}
