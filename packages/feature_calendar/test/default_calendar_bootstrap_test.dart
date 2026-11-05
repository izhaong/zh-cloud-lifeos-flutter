import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// parity#156：空库首启必须有一条默认日历，否则新建日程只会提示
/// 「没有可用日历，无法保存」，事件永远建不出来。
void main() {
  test('空库兜底建一条默认「日历」', () async {
    final repo = _FakeCalendarRepo();
    final cal = await ensureDefaultCalendar(repo);

    expect(cal, isNotNull);
    expect(cal!.title, '日历');
    expect(cal.isDefault, isTrue);
    expect(cal.kind, CalendarKind.local);
    expect(repo.calendars.single.id, cal.id);
  });

  test('已有默认日历时不新建（幂等）', () async {
    final repo = _FakeCalendarRepo()
      ..calendars.add(
        const Calendar(
          id: 'c1',
          title: '家庭',
          colorArgb: 0xFF34C759,
          isDefault: true,
        ),
      );

    final cal = await ensureDefaultCalendar(repo);

    expect(cal!.id, 'c1');
    expect(repo.calendars.length, 1);
  });

  test('有本地日历但没默认时补默认，不再新建', () async {
    final repo = _FakeCalendarRepo()
      ..calendars.add(
        const Calendar(id: 'c1', title: '工作', colorArgb: 0xFF007AFF),
      );

    final cal = await ensureDefaultCalendar(repo);

    expect(cal!.id, 'c1');
    expect(repo.calendars.length, 1);
    expect(repo.defaultId, 'c1');
  });
}

class _FakeCalendarRepo implements CalendarRepository {
  final List<Calendar> calendars = [];
  String? defaultId;

  @override
  Stream<List<Calendar>> watchCalendars() =>
      Stream.value(List<Calendar>.unmodifiable(calendars));

  @override
  Future<void> upsertCalendar(Calendar c) async {
    calendars
      ..removeWhere((e) => e.id == c.id)
      ..add(c);
    if (c.isDefault) defaultId = c.id;
  }

  @override
  Future<void> setDefaultCalendar(String id) async {
    defaultId = id;
    for (var i = 0; i < calendars.length; i++) {
      final c = calendars[i];
      calendars[i] = Calendar(
        id: c.id,
        title: c.title,
        colorArgb: c.colorArgb,
        kind: c.kind,
        isDefault: c.id == id,
      );
    }
  }

  @override
  Future<void> deleteCalendar(String id) async =>
      calendars.removeWhere((c) => c.id == id);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) => Stream.value(const <CalendarEvent>[]);

  @override
  Future<CalendarEvent?> getEvent(String id) async => null;

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
  }) async => const <CalendarEvent>[];

  @override
  Future<void> setVisibility({
    String? id,
    bool? visible,
    bool? allVisible,
    String? onlyId,
  }) async {}

  @override
  Future<void> reorderCalendars(List<String> ids) async {}

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(CalendarPreference.defaults);

  @override
  Future<void> savePreference(CalendarPreference p) async {}
}
