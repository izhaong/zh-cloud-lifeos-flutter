import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #283：侧栏取消勾选某本日历后，主视图（日/周/月共用 occurrencesProvider）
/// 必须立刻不再出现该日历的事件；再勾上恢复。
void main() {
  late _Repo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _Repo();
    container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        // occurrencesProvider 还会聚合「已安排的提醒事项」；不注入会让该分支
        // 永远 AsyncLoading，provider 就不发射（.future 挂住）
        calendarReminderRepositoryProvider.overrideWithValue(
          InMemoryReminderRepository(seedSampleData: false),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('隐藏的日历 → 其事件从 occurrences 里消失；可见的仍在', () async {
    repo.calendars = const [
      Calendar(id: 'c1', title: '日历', colorArgb: 0xFF007AFF, isVisible: false),
      Calendar(id: 'c2', title: '工作', colorArgb: 0xFF34C759, isVisible: true),
    ];
    repo.events = [
      _allDay('e1', 'c1', '体检', DateTime(2026, 10, 28)),
      _allDay('e2', 'c2', '周会', DateTime(2026, 10, 28)),
    ];

    final occ = await _occurrences(container);

    expect(occ.map((o) => o.title), contains('周会'));
    expect(
      occ.map((o) => o.title),
      isNot(contains('体检')),
      reason: '取消勾选的日历事件必须从视图消失（TC-CAL-UI-107/124）',
    );
  });

  test('重新勾上 → 事件回来', () async {
    repo.calendars = const [
      Calendar(id: 'c1', title: '日历', colorArgb: 0xFF007AFF, isVisible: true),
    ];
    repo.events = [_allDay('e1', 'c1', '体检', DateTime(2026, 10, 28))];

    final occ = await _occurrences(container);
    expect(occ.map((o) => o.title), contains('体检'));
  });

  test('日历尚未加载（空列表）时不过滤，避免首帧事件闪没', () async {
    repo.calendars = const [];
    repo.events = [_allDay('e1', 'c1', '体检', DateTime(2026, 10, 28))];

    final occ = await _occurrences(container);
    expect(occ.map((o) => o.title), contains('体检'));
  });
}

Future<List<CalendarOccurrence>> _occurrences(ProviderContainer c) async {
  // 订阅一次再等两拍：流 provider 的首值在微任务里到达；用 .future 会在
  // 依赖仍 AsyncLoading 时挂死（先前踩过）
  final range = (DateTime(2026, 10, 26), DateTime(2026, 11, 2));
  final sub = c.listen(occurrencesProvider(range), (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 20; i++) {
    final value = c.read(occurrencesProvider(range)).value;
    if (value != null) return value;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return const [];
}

CalendarEvent _allDay(String id, String calendarId, String title, DateTime day) =>
    CalendarEvent(
      id: id,
      calendarId: calendarId,
      uid: id,
      title: title,
      startAt: DateTime.utc(day.year, day.month, day.day),
      endAt: DateTime.utc(day.year, day.month, day.day + 1),
      allDay: true,
      timeZone: 'UTC',
      updatedAt: DateTime.utc(2026, 10, 1),
    );

class _Repo implements CalendarRepository {
  List<Calendar> calendars = const [];
  List<CalendarEvent> events = const [];

  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(calendars);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) => Stream.value(events);

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(const CalendarPreference());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
