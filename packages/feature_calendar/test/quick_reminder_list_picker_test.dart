import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';
import 'support/life_test_app.dart';

/// parity#401：日历侧「新建提醒」必须能指定目标列表，
/// 不再恒写第一个普通列表（矩阵 H2 / TC-CAL-UI-191）。
void main() {
  const personal = ReminderList(id: 'list.personal', title: '个人');
  const work = ReminderList(id: 'list.work', title: '工作');

  late SharedPreferences prefs;
  final controller = kalender.DefaultEventsController();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// 直接把面板挂在一个按钮后面：这几个用例断的是面板自身的契约，
  /// 不需要整棵日历树（工具栏接线另有单独一条用例覆盖）。
  Future<void> pumpDialog(
    WidgetTester tester, {
    required List<ReminderList> lists,
    required ValueNotifier<QuickReminderDraft?> out,
    Size size = const Size(900, 900),
  }) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      lifeTestHost(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              out.value = await showQuickReminderDialog(
                context,
                lists: lists,
                now: DateTime(2026, 10, 29, 9),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('面板里点第二个列表 → 返回的 listId 就是它', (tester) async {
    final out = ValueNotifier<QuickReminderDraft?>(null);
    await pumpDialog(tester, lists: const [personal, work], out: out);

    expect(
      find.byKey(const Key('quick_reminder_list_list.work')),
      findsOneWidget,
      reason: '多列表时必须把候选列表摊在面板里，否则用户无从指定',
    );

    await tester.enterText(
      find.byKey(const Key('quick_reminder_input')),
      '买牛奶',
    );
    await tester.tap(find.byKey(const Key('quick_reminder_list_list.work')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_reminder_create')));
    await tester.pumpAndSettle();

    final draft = out.value;
    expect(draft, isNotNull);
    expect(draft!.listId, 'list.work');
    expect(draft.event.title, '买牛奶');
    out.dispose();
  });

  testWidgets('不碰列表行仍落首个列表（默认口径没被改坏）', (tester) async {
    final out = ValueNotifier<QuickReminderDraft?>(null);
    await pumpDialog(tester, lists: const [personal, work], out: out);

    await tester.enterText(
      find.byKey(const Key('quick_reminder_input')),
      '取快递',
    );
    await tester.tap(find.byKey(const Key('quick_reminder_create')));
    await tester.pumpAndSettle();

    expect(out.value?.listId, 'list.personal');
    out.dispose();
  });

  testWidgets('取消回 null；且日历侧取消不会落库任何提醒', (tester) async {
    final reminders = InMemoryReminderRepository(seedSampleData: false);
    await reminders.upsertList(personal);
    await reminders.upsertList(work);
    prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(_Repo()),
          sidebarPrefsProvider.overrideWithValue(prefs),
          kalenderEventsControllerProvider.overrideWithValue(controller),
          calendarReminderRepositoryProvider.overrideWithValue(reminders),
        ],
        child: lifeTestHost(
          const Scaffold(
            body: CalendarScaffold(pinnedViewMode: CalendarViewMode.day),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick_create_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_create_reminder')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick_reminder_input')),
      '别写进去',
    );
    await tester.tap(find.byKey(const Key('quick_reminder_cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick_reminder_dialog')), findsNothing);
    final items = await reminders.watchItems().first;
    expect(items, isEmpty, reason: '取消也写库 ⇒ 凭空多出提醒（面板必须回 null）');
  });

  testWidgets('只有一个候选列表时显出落点，但不摆可点的假选择', (tester) async {
    final out = ValueNotifier<QuickReminderDraft?>(null);
    await pumpDialog(tester, lists: const [personal], out: out);

    expect(
      find.byKey(const Key('quick_reminder_list_static')),
      findsOneWidget,
      reason: '单列表也要让用户看到提醒写到哪，否则等于静默改数据',
    );
    expect(find.text('个人'), findsWidgets);
    expect(
      find.byKey(const Key('quick_reminder_list_list.personal')),
      findsNothing,
      reason: '只有一个候选时摆「选择」控件是假交互',
    );
    out.dispose();
  });

  testWidgets('375 紧凑宽度下面板不溢出', (tester) async {
    final out = ValueNotifier<QuickReminderDraft?>(null);
    await pumpDialog(
      tester,
      lists: const [personal, work],
      out: out,
      size: const Size(375, 844),
    );
    expect(tester.takeException(), isNull);
    out.dispose();
  });

  testWidgets('工具栏「新建提醒」把用户选的列表写进仓库', (tester) async {
    final reminders = InMemoryReminderRepository(seedSampleData: false);
    await reminders.upsertList(personal);
    await reminders.upsertList(work);
    prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(_Repo()),
          sidebarPrefsProvider.overrideWithValue(prefs),
          kalenderEventsControllerProvider.overrideWithValue(controller),
          calendarReminderRepositoryProvider.overrideWithValue(reminders),
        ],
        child: lifeTestHost(
          const Scaffold(
            body: CalendarScaffold(pinnedViewMode: CalendarViewMode.day),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick_create_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_create_reminder')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('quick_reminder_input')),
      '评审契约',
    );
    await tester.tap(find.byKey(const Key('quick_reminder_list_list.work')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_reminder_create')));
    await tester.pumpAndSettle();

    final items = await reminders.watchItems().first;
    final created = items.where((i) => i.title == '评审契约').toList();
    expect(created, hasLength(1), reason: '提醒没落库 ⇒ 快捷入口或写库参数没接上');
    expect(
      created.single.listId,
      'list.work',
      reason: '#401 的核心：落点必须是用户选的列表，而不是首个',
    );
  });
}

class _Repo implements CalendarRepository {
  final List<CalendarEvent> visible = [];
  final _events = StreamController<List<CalendarEvent>>.broadcast();
  CalendarPreference preference = const CalendarPreference();
  final _prefs = StreamController<CalendarPreference>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield const [
      Calendar(id: 'c1', title: '日历', colorArgb: 0xFF007AFF, isDefault: true),
    ];
  }

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield List<CalendarEvent>.unmodifiable(visible);
    yield* _events.stream;
  }

  @override
  Future<CalendarEvent?> getEvent(String id) async =>
      visible.where((e) => e.id == id).firstOrNull;

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
  Stream<CalendarPreference> watchPreference() async* {
    yield preference;
    yield* _prefs.stream;
  }

  @override
  Future<void> savePreference(CalendarPreference p) async {
    preference = p;
    _prefs.add(p);
  }
}
