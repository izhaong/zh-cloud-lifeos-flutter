import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_note/feature_note.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/main.dart';
import 'package:life_launcher/shell/pinned_tabs_service.dart';
import 'package:life_launcher/shell_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F-03（TC-NOTE-UI-100 前置）：基座·记录 Tab 接入 feature_note；
/// 验收：点「记录」进入 NoteTabEntry（标题「记录」+ 空态「没有备忘录」），
/// 不进日历（无 calendar_toolbar）也不进任务区（无「列表」标题）。
void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('F-03 基座·记录：Tab 切到记录出现 NoteTabEntry，不进日历/任务',
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
            InMemoryReminderRepository(seedSampleData: false),
          ),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository(),
          ),
          noteRepositoryProvider.overrideWithValue(
            InMemoryNoteRepository(),
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

    // 点「记录」Tab → NoteTabEntry
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();

    // 记录首页在屏（AppBar 标题「记录」 + 空态）
    expect(find.text('记录'), findsWidgets);
    expect(find.text('没有备忘录'), findsOneWidget);
    // 不进日历：无日历工具栏
    expect(find.byKey(const Key('calendar_toolbar')), findsNothing);
    // 不进任务区：无「列表」标题
    expect(find.text('列表'), findsNothing);
  });
}

/// 测试假仓库（复用 tc_cal_ui_311 同款口径；本测只关心记录 Tab）。
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
