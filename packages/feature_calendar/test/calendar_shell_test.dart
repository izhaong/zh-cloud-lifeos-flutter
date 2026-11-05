import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

/// F-03 壳骨架契约（TC-CAL-UI-001；契约 §5.4/§5.5/§8.5）。
void main() {
  // TC-CAL-UI-001：进入日历 → 出现工具栏 Key calendar_toolbar；任务列表标题「列表」不可见
  testWidgets('TC-CAL-UI-001 进入日历出现工具栏', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository(),
          ),
        ],
        child: lifeTestHost(const CalendarTabEntry()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar_toolbar')), findsOneWidget);
    expect(find.text('列表'), findsNothing);
    expect(find.textContaining('待拆入'), findsNothing);
  });

  // 仓库 Provider 未注入时显式失败（照 reminderRepositoryProvider 口径）
  test('calendarRepositoryProvider 未注入即抛错', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Riverpod 3 将 Provider 内抛错包装为 ProviderException（未导出类型），
    // 断言包装消息携带未注入提示
    Object? caught;
    try {
      container.read(calendarRepositoryProvider);
    } catch (e) {
      caught = e;
    }
    expect(caught, isNotNull, reason: '未注入应显式抛错');
    expect(caught.toString(), contains('CalendarRepository 未注入'));
  });

  // 视图模式 Provider（F-05 消费）
  test('viewModeProvider 默认 day 且可切换', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(viewModeProvider), CalendarViewMode.day);
    container.read(viewModeProvider.notifier).set(CalendarViewMode.month);
    expect(container.read(viewModeProvider), CalendarViewMode.month);
  });

  // anchorDateProvider 默认今天（本地零点）
  test('anchorDateProvider 默认今天零点', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final now = DateTime.now();
    final anchor = container.read(anchorDateProvider);
    expect(anchor.year, now.year);
    expect(anchor.month, now.month);
    expect(anchor.day, now.day);
  });
}

/// 测试假仓库（F-03 骨架只需流存在；行为随 F-04+ 充实）。
class _FakeCalendarRepository implements CalendarRepository {
  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(const []);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) {
    return Stream.value(const []);
  }

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
  }) async {
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
  }) async {
    return const [];
  }

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(CalendarPreference.defaults);

  @override
  Future<void> savePreference(CalendarPreference p) async {}
}
