import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// F-16 本地节假日与订阅占位（TC-CAL-UI-160/162）。
void main() {
  test('TC-CAL-UI-162 中国节假日生成只读日历（元旦当天全天）', () async {
    final repo = _Repo();
    final calendar = await ensureLocalHolidayCalendar(repo, year: 2026);

    expect(calendar.kind, CalendarKind.holiday);
    expect(repo.calendars.any((c) => c.id == kHolidayCalendarId), isTrue,
        reason: '节假日日历已落库');
    final newYear = repo.events.where((e) =>
        e.startAt.microsecondsSinceEpoch ==
            DateTime.utc(2026, 1, 1).microsecondsSinceEpoch &&
        e.allDay);
    expect(newYear, isNotEmpty, reason: '元旦当天有全天条');
  });

  test('TC-CAL-UI-162 关闭节假日 → 日历不可见', () async {
    final repo = _Repo();
    await ensureLocalHolidayCalendar(repo, year: 2026, visible: false);
    expect(repo.visibility[kHolidayCalendarId], isFalse);
  });

  testWidgets('TC-CAL-UI-160 未登录订阅只存 URL 且提示登录后', (tester) async {
    final repo = _Repo();
    final container = ProviderContainer(overrides: [
      calendarRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showLocalSubscriptionDialog(context,
                  repository: repo),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('登录后'), findsOneWidget,
        reason: '文案含登录后');
    await tester.enterText(find.byKey(const Key('subscription_url')),
        'https://example.com/feed.ics');
    await tester.tap(find.byKey(const Key('subscription_save')));
    await tester.pumpAndSettle();

    final created = repo.calendars.single;
    expect(created.kind, CalendarKind.subscription);
    expect(created.sourceUrl, 'https://example.com/feed.ics');
    expect(repo.events, isEmpty, reason: '本地版不拉取任何事件');
  });
}

class _Repo implements CalendarRepository {
  final List<Calendar> calendars = [];
  final List<CalendarEvent> events = [];
  final Map<String, bool> visibility = {};
  final _calendars = StreamController<List<Calendar>>.broadcast();

  @override
  Future<CalendarEvent?> getEvent(String id) async => null;

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(calendars);
    yield* _calendars.stream;
  }

  @override
  Future<void> upsertCalendar(Calendar c) async {
    calendars.removeWhere((x) => x.id == c.id);
    calendars.add(c);
    _calendars.add(List<Calendar>.unmodifiable(calendars));
  }

  @override
  Future<void> setVisibility(
      {String? id, bool? visible, bool? allVisible, String? onlyId}) async {
    if (id != null && visible != null) {
      visibility[id] = visible;
    }
  }

  @override
  Future<String> upsertEvent(CalendarEvent e,
      {EditScope scope = EditScope.all, DateTime? occurrenceStart}) async {
    events.removeWhere((x) => x.id == e.id);
    events.add(e);
    return e.id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
