import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// parity#228：全天区拖多日 → 跨天全天草稿（当地 00:00 → 次日 00:00 排他），
/// 不能退化成「开始那天 00:00–01:00」的定时草稿。
void main() {
  CalendarEvent? draft;
  CalendarViewCallbacks callbacks() => CalendarViewCallbacks(
    repo: _NoopRepo(),
    preference: CalendarPreference.defaults,
    timeZone: 'America/New_York',
    setDraft: (d) => draft = d,
  );

  test('周一拖到周三 → 周一起、周四 00:00 止的全天事件', () {
    draft = null;
    // kalender 全天区拖拽常见形态：start 周一 00:00，end 周三 00:00（或 01:00）
    callbacks().onAllDayDraftCreate(
      DateTime(2026, 10, 26, 0, 0),
      DateTime(2026, 10, 28, 0, 0),
    );

    expect(draft, isNotNull);
    expect(draft!.allDay, isTrue, reason: '必须保持全天');
    // 当地 10/26 00:00 EDT → 04:00Z；10/28 00:00 EDT → 04:00Z（end 排他 = 周三结束）
    expect(draft!.startAt, DateTime.utc(2026, 10, 26, 4));
    expect(draft!.endAt, DateTime.utc(2026, 10, 28, 4));
    expect(draft!.timeZone, 'America/New_York');
  });

  test('拖拽带 01:00 时刻也按日期归一', () {
    draft = null;
    callbacks().onAllDayDraftCreate(
      DateTime(2026, 10, 26, 0, 0),
      DateTime(2026, 10, 28, 1, 0),
    );
    expect(draft!.startAt, DateTime.utc(2026, 10, 26, 4));
    expect(draft!.endAt, DateTime.utc(2026, 10, 28, 4));
  });

  group('全天区拖拽判据（kalender 不传 isAllDay）', () {
    test('跨天且两端零点 → 全天', () {
      expect(
        CalendarViewCallbacks.looksLikeAllDayRange(
          DateTime(2026, 10, 26),
          DateTime(2026, 10, 29),
        ),
        isTrue,
      );
    });
    test('时间轴 10:00–11:00 → 不是全天', () {
      expect(
        CalendarViewCallbacks.looksLikeAllDayRange(
          DateTime(2026, 10, 26, 10),
          DateTime(2026, 10, 26, 11),
        ),
        isFalse,
      );
    });
    test('同一天零点区间（<1 天）→ 不是全天', () {
      expect(
        CalendarViewCallbacks.looksLikeAllDayRange(
          DateTime(2026, 10, 26),
          DateTime(2026, 10, 26, 1),
        ),
        isFalse,
      );
    });
  });

  test('同一天拖（end 不晚于 start）兜底成一天', () {
    draft = null;
    callbacks().onAllDayDraftCreate(
      DateTime(2026, 10, 26, 0, 0),
      DateTime(2026, 10, 26, 0, 0),
    );
    expect(draft!.endAt, DateTime.utc(2026, 10, 27, 4));
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
