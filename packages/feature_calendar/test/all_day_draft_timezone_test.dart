import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// parity#219：全天草稿必须以**设备时区**的当地零点为锚。
/// 写死 'UTC' 时，UTC−4 时区的「今天 00:00」渲染成前一天。
void main() {
  test('纽约时区：onDayTap(本地 10/28) 归一后墙上日期仍是 28', () async {
    final repo = _NoopRepo();
    CalendarEvent? draft;
    final callbacks = CalendarViewCallbacks(
      repo: repo,
      preference: CalendarPreference.defaults,
      timeZone: 'America/New_York',
      setDraft: (d) => draft = d,
    );

    callbacks.onDayTap(DateTime(2026, 10, 28));

    expect(draft, isNotNull);
    expect(draft!.allDay, isTrue);
    expect(draft!.timeZone, 'America/New_York');
    // 当地 10/28 00:00 EDT == 10/28 04:00Z
    expect(draft!.startAt.toUtc(), DateTime.utc(2026, 10, 28, 4));
    expect(draft!.endAt.toUtc(), DateTime.utc(2026, 10, 29, 4));

    // 保存路径的归一不能把日期挪走
    final normalized = normalizeAllDay(draft!);
    expect(
      wallTimeOf(normalized.startAt, 'America/New_York').day,
      28,
      reason: '归一后墙上日期必须仍是 28 号',
    );
  });

  test('timed 草稿也带设备时区（不再写死 UTC）', () async {
    CalendarEvent? draft;
    final callbacks = CalendarViewCallbacks(
      repo: _NoopRepo(),
      preference: CalendarPreference.defaults,
      timeZone: 'America/New_York',
      setDraft: (d) => draft = d,
    );

    callbacks.onDraftCreate(
      DateTime(2026, 10, 28, 10),
      DateTime(2026, 10, 28, 11),
    );

    expect(draft!.timeZone, 'America/New_York');
    expect(draft!.allDay, isFalse);
  });
}

class _NoopRepo implements CalendarRepository {
  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(const []);
  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) => Stream.value(const []);
  @override
  Future<CalendarEvent?> getEvent(String id) async => null;
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
  }) async => e.id;
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
  }) async => const [];
  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(CalendarPreference.defaults);
  @override
  Future<void> savePreference(CalendarPreference p) async {}
}
