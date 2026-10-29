// #400：18 个快捷键 Intent 全部注册了 CallbackAction，但 scaffold 只注入 8 个
// 回调——其余按下去走 `?.call()`，绑定在、功能不在。
//
// 本文件对着**真实 CalendarScaffold**（不是 CalendarShortcutActions 裸壳）按键，
// 断言每条快捷键落到可观察的后果：同步被调用 / 面板打开 / 草稿写入 /
// 仓库收到 upsert·delete / anchorDate 改变。
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'support/life_test_app.dart';

Future<void> _combo(WidgetTester tester, List<LogicalKeyboardKey> mods,
    LogicalKeyboardKey key) async {
  for (final m in mods) {
    await tester.sendKeyDownEvent(m);
  }
  await tester.sendKeyEvent(key);
  for (final m in mods.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await tester.pumpAndSettle();
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CalendarScaffold)));

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  late _Repo repo;
  late int syncCalls;

  Future<void> pump(WidgetTester tester) async {
    repo = _Repo();
    syncCalls = 0;
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 700)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repo),
          calendarSyncTriggerProvider.overrideWithValue(() async {
            syncCalls++;
          }),
        ],
        child: lifeTestHost(const CalendarScaffold()),
      ),
    );
    await tester.pumpAndSettle();
  }

  void selectToday(WidgetTester tester) {
    _containerOf(tester).read(selectedOccurrenceProvider.notifier)
        .select(repo.occurrence);
  }

  testWidgets('TC-CAL-UI-501 ⌘R 触发同步（此前静默）', (tester) async {
    await pump(tester);
    await _combo(tester, [LogicalKeyboardKey.metaLeft], LogicalKeyboardKey.keyR);
    expect(syncCalls, 1, reason: '⌘R 必须真的调同步触发器，而不是只有绑定');
  });

  testWidgets('TC-CAL-UI-501 ⇧⌘T 打开跳到日期面板并按输入改 anchorDate',
      (tester) async {
    await pump(tester);
    await _combo(tester,
        [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.keyT);
    expect(find.byKey(const Key('jump_to_date_dialog')), findsOneWidget,
        reason: '⇧⌘T 应打开跳到日期面板');

    await tester.enterText(
        find.byKey(const Key('jump_to_date_field')), '2030-05-06');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('jump_to_date_go')));
    await tester.pumpAndSettle();

    final anchor = _containerOf(tester).read(anchorDateProvider);
    expect(anchor.year, 2030);
    expect(anchor.month, 5);
    expect(anchor.day, 6);
  });

  testWidgets('TC-CAL-UI-501 ⌘I 显示所选日程的信息面板', (tester) async {
    await pump(tester);
    selectToday(tester);
    await _combo(tester, [LogicalKeyboardKey.metaLeft], LogicalKeyboardKey.keyI);
    expect(find.byKey(const Key('occurrence_info_dialog')), findsOneWidget);
    expect(find.text(repo.occurrence.title), findsWidgets);
  });

  testWidgets('TC-CAL-UI-501 ⌘E 用所选日程打开编辑草稿', (tester) async {
    await pump(tester);
    selectToday(tester);
    await _combo(tester, [LogicalKeyboardKey.metaLeft], LogicalKeyboardKey.keyE);
    final draft = _containerOf(tester).read(draftEventProvider);
    expect(draft?.id, repo.event.id, reason: '⌘E 应把所选日程装进草稿');
  });

  testWidgets('TC-CAL-UI-501 ⌥⌘I 打开 Inspector（同 ⌘E 的编辑面）',
      (tester) async {
    await pump(tester);
    selectToday(tester);
    await _combo(tester,
        [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.altLeft],
        LogicalKeyboardKey.keyI);
    final draft = _containerOf(tester).read(draftEventProvider);
    expect(draft?.id, repo.event.id);
  });

  testWidgets('TC-CAL-UI-501 对照：无所选时 ⌘E 不写草稿（防恒真）',
      (tester) async {
    await pump(tester);
    await _combo(tester, [LogicalKeyboardKey.metaLeft], LogicalKeyboardKey.keyE);
    expect(_containerOf(tester).read(draftEventProvider), isNull,
        reason: '没有选中项时不该凭空造草稿');
  });

  testWidgets('TC-CAL-UI-501 ⌃⌥→ 把所选日程整体后移一天', (tester) async {
    await pump(tester);
    selectToday(tester);
    await _combo(tester,
        [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.altLeft],
        LogicalKeyboardKey.arrowRight);
    // 假仓库 upsertEvent 会把 event 换成回写的实例，判据只认落库那条的绝对时刻。
    expect(repo.upserted, hasLength(1));
    expect(repo.upserted.single.startAt, DateTime.utc(2026, 3, 5, 9));
    expect(repo.upserted.single.endAt, DateTime.utc(2026, 3, 5, 10));
  });

  testWidgets('TC-CAL-UI-501 Delete 删除所选日程并清空所选', (tester) async {
    await pump(tester);
    selectToday(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(repo.deleted, contains(repo.event.id));
    expect(_containerOf(tester).read(selectedOccurrenceProvider), isNull);
  });

  testWidgets('TC-CAL-UI-501 ⌥⌘S 打开订阅面板', (tester) async {
    await pump(tester);
    await _combo(tester,
        [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.altLeft],
        LogicalKeyboardKey.keyS);
    expect(find.byKey(const Key('subscription_dialog')), findsOneWidget);
  });

  testWidgets('TC-CAL-UI-501 ⇧⌘N 打开新建日历面板', (tester) async {
    await pump(tester);
    await _combo(tester,
        [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.shiftLeft],
        LogicalKeyboardKey.keyN);
    expect(find.byKey(const Key('dialog-done')), findsOneWidget);
  });
}

/// 行为可断言的假仓库：记录 upsert/delete，并把所选日程喂给 getEvent。
class _Repo implements CalendarRepository {
  _Repo() {
    event = CalendarEvent(
      id: 'evt-1',
      calendarId: 'cal-1',
      uid: 'uid-1',
      title: '评审会',
      startAt: DateTime.utc(2026, 3, 4, 9),
      endAt: DateTime.utc(2026, 3, 4, 10),
      timeZone: 'UTC',
      updatedAt: DateTime.utc(2026, 3, 1),
    );
    occurrence = CalendarOccurrence(
      eventId: event.id,
      masterEventId: event.id,
      calendarId: event.calendarId,
      colorArgb: 0xFF007AFF,
      title: event.title,
      allDay: false,
      start: event.startAt,
      end: event.endAt,
      isRecurring: false,
      isException: false,
    );
  }

  late CalendarEvent event;
  late CalendarOccurrence occurrence;
  final List<CalendarEvent> upserted = [];
  final List<String> deleted = [];

  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value([
        const Calendar(id: 'cal-1', title: '工作', colorArgb: 0xFF007AFF),
      ]);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) =>
      Stream.value([event]);

  @override
  Future<CalendarEvent?> getEvent(String id) async =>
      id == event.id ? event : null;

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
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    upserted.add(e);
    event = e;
    return e.id;
  }

  @override
  Future<void> deleteEvent(
    String id, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    deleted.add(id);
  }

  @override
  Future<void> moveEvent(String id, String targetCalendarId) async {}

  @override
  Future<List<CalendarEvent>> search(
    String keyword, {
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) async =>
      const [];

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(CalendarPreference.defaults);

  @override
  Future<void> savePreference(CalendarPreference p) async {}
}
