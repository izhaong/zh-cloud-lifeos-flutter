import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/main.dart';
import 'package:life_launcher/shell/pinned_tabs_service.dart';
import 'package:life_launcher/shell_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TC-CAL-UI-311（原 TC-UI-311 改写）：基座·日历 → CalendarTabEntry 不再是占位。
/// TC-CAL-UI-001：点「日历」后出现工具栏 Key `calendar_toolbar`；任务区标题「列表」不可见。
void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('TC-CAL-UI-311/001 基座·日历：Tab 切到日历出现工具栏不进任务区',
      (tester) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view
      ..physicalSize = const Size(375, 812)
      ..devicePixelRatio = 1.0;
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(
            InMemoryReminderRepository(),
          ),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository(),
          ),
          pinnedTabsServiceProvider.overrideWithValue(
            PinnedTabsService(prefs),
          ),
          shellBadgeCountsProvider.overrideWithValue(const {}),
        ],
        child: const LifeLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 初始任务区在屏（首页 AppBar 大标题=「列表」）
    expect(find.text('列表'), findsOneWidget);

    // 点「日历」Tab → CalendarTabEntry（工具栏 Key calendar_toolbar）
    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar_toolbar')), findsOneWidget);
    expect(find.textContaining('待拆入'), findsNothing);
    expect(find.text('列表'), findsNothing); // 任务区不在前台
  });
}

/// 测试假仓库（骨架：流存在即可；行为随 F-04+ 充实）。
class _FakeCalendarRepository implements CalendarRepository {
  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(const []);

  @override
  Stream<List<CalendarEvent>> watchEvents(
      {required DateTime from, required DateTime to, Set<String>? calendarIds}) {
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
  Future<void> setVisibility(
      {String? id, bool? visible, bool? allVisible, String? onlyId}) async {}

  @override
  Future<String> upsertEvent(CalendarEvent e,
      {EditScope scope = EditScope.all, DateTime? occurrenceStart}) async {
    return e.id;
  }

  @override
  Future<void> deleteEvent(String id,
      {EditScope scope = EditScope.all, DateTime? occurrenceStart}) async {}

  @override
  Future<void> moveEvent(String id, String targetCalendarId) async {}

  @override
  Future<List<CalendarEvent>> search(String keyword,
      {DateTime? from, DateTime? to, int limit = 50}) async {
    return const [];
  }

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(CalendarPreference.defaults);

  @override
  Future<void> savePreference(CalendarPreference p) async {}
}
