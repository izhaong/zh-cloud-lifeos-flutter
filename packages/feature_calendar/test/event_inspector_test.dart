import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';

/// F-08 Inspector 与表单字段（TC-CAL-UI-132～134/136/137；契约 §5.4）。
void main() {
  late _MutableRepo repo;
  late ProviderContainer container;
  final controller = kalender.DefaultEventsController();

  CalendarEvent draftEvent() => CalendarEvent(
        id: 'e1',
        calendarId: 'c1',
        uid: 'u1',
        title: '周会',
        startAt: DateTime.utc(2026, 10, 24, 10),
        endAt: DateTime.utc(2026, 10, 24, 11),
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 24),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    controller.clearEvents();
    repo = _MutableRepo();
    container = ProviderContainer(overrides: [
      calendarRepositoryProvider.overrideWithValue(repo),
      sidebarPrefsProvider.overrideWith((ref) => null),
      kalenderEventsControllerProvider.overrideWithValue(controller),
    ]);
  });

  tearDown(() => container.dispose());

  Future<void> pumpInspector(WidgetTester tester, {CalendarEvent? event}) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: EventInspectorPane(
            initialEvent: event ?? draftEvent(),
            onSaved: () {},
            onClose: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  // TC-CAL-UI-132：字段顺序（从上到下 14 个字段全部出现）
  testWidgets('TC-CAL-UI-132 字段顺序完整', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpInspector(tester);
    final keys = [
      'event_field_title',
      'event_field_location',
      'event_field_all_day',
      'event_field_start',
      'event_field_end',
      'event_field_timezone',
      'event_field_repeat',
      'event_field_travel',
      'event_field_alerts',
      'event_field_calendar',
      'event_field_availability',
      'event_field_private',
      'event_field_url',
      'event_field_notes',
    ];
    for (final k in keys) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: '字段 $k 存在');
    }
    // 顺序：按 dy 单调递增
    final dys = [
      for (final k in keys)
        tester.getTopLeft(find.byKey(Key(k))).dy,
    ];
    for (var i = 1; i < dys.length; i++) {
      expect(dys[i], greaterThan(dys[i - 1]), reason: '第 $i 个字段在下方');
    }
  });

  // TC-CAL-UI-133：改标题保存 → 仓库 upsertEvent 收到新标题
  testWidgets('TC-CAL-UI-133 保存回写标题', (tester) async {
    await pumpInspector(tester);
    await tester.enterText(find.byKey(const Key('event_field_title')), '预算评审');
    await tester.pump();
    await tester.tap(find.byKey(const Key('event_inspector_save')));
    await tester.pumpAndSettle();

    expect(repo.upserted, isNotEmpty);
    expect(repo.upserted.last.title, '预算评审');
  });

  // TC-CAL-UI-134：备注写两行，再次打开仍在（同一事件 id 重进面板）
  testWidgets('TC-CAL-UI-134 备注保存回读', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpInspector(tester);
    await tester.enterText(
        find.byKey(const Key('event_field_notes')), '第一行\n第二行');
    await tester.pump();
    await tester.tap(find.byKey(const Key('event_inspector_save')));
    await tester.pumpAndSettle();
    expect(repo.upserted.last.notes, '第一行\n第二行');

    // 重开（草稿=已保存事件）→ 备注仍在
    await pumpInspector(tester, event: repo.upserted.last);
    expect(find.text('第一行\n第二行'), findsOneWidget, reason: '再次打开备注仍在');
  });

  // TC-CAL-UI-136：换日历 → 保存后 calendarId 变化
  testWidgets('TC-CAL-UI-136 换日历', (tester) async {
    // 侧栏日历数据（fake repo 返回两个日历）
    repo.calendars.addAll([
      _cal('c1', '工作'),
      _cal('c2', '家庭'),
    ]);
    await pumpInspector(tester);
    await tester.tap(find.byKey(const Key('event_field_calendar_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('家庭').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event_inspector_save')));
    await tester.pumpAndSettle();

    expect(repo.upserted.last.calendarId, 'c2', reason: '日历换成 c2');
  });

  // 审查补充：无日历时保存 → 明确提示、不写库不关闭（不静默失败）
  testWidgets('无日历保存给出明确提示', (tester) async {
    final draft = draftEvent().copy(id: kDraftEventId, calendarId: '');
    var savedCalled = false;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: EventInspectorPane(
            initialEvent: draft,
            onSaved: () => savedCalled = true,
            onClose: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('event_inspector_save')));
    await tester.pumpAndSettle();

    expect(repo.upserted, isEmpty, reason: '不写库');
    expect(savedCalled, isFalse, reason: '不关闭');
    expect(find.byKey(const Key('event_inspector_blocked_hint')),
        findsOneWidget, reason: '阻塞提示可见');
    expect(find.text('没有可用日历，无法保存'), findsOneWidget);
  });

  // 审查补充：新建草稿 id='draft' 保存 → 生成新 id（两次保存不互相覆盖）
  testWidgets('新建草稿保存生成新 id', (tester) async {
    final draft = draftEvent().copy(id: kDraftEventId, calendarId: 'c1');
    repo.calendars.add(_cal('c1', '工作'));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: EventInspectorPane(
            initialEvent: draft,
            onSaved: () {},
            onClose: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event_inspector_save')));
    await tester.pumpAndSettle();

    final first = repo.upserted.single;
    expect(first.id, isNot(kDraftEventId), reason: '保存换新 id');
    expect(first.calendarId, 'c1', reason: '日历保留');

    // 第二次新建草稿保存 → 又一个不同 id
    final draft2 = draftEvent()
        .copy(id: kDraftEventId, calendarId: 'c1', title: '第二个');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: EventInspectorPane(
            initialEvent: draft2,
            onSaved: () {},
            onClose: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('event_field_title')), '第二个');
    await tester.pump();
    await tester.tap(find.byKey(const Key('event_inspector_save')));
    await tester.pumpAndSettle();

    expect(repo.upserted.length, 2);
    expect(repo.upserted[1].id, isNot(repo.upserted[0].id),
        reason: '两次新建不互相覆盖');
  });

  // TC-CAL-UI-137：空标题点保存 → 不关闭不写库
  testWidgets('TC-CAL-UI-137 空标题禁止保存', (tester) async {
    var savedCalled = false;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: EventInspectorPane(
            initialEvent: draftEvent(),
            onSaved: () => savedCalled = true,
            onClose: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('event_field_title')), '');
    await tester.pump();
    await tester.tap(find.byKey(const Key('event_inspector_save')));
    await tester.pumpAndSettle();

    expect(repo.upserted, isEmpty, reason: '不写库');
    expect(savedCalled, isFalse, reason: '不触发保存回调（不关闭）');
    expect(find.byKey(const Key('event_inspector_pane')), findsOneWidget,
        reason: '面板仍在');
    expect(find.byKey(const Key('event_inspector_pane')), findsOneWidget);
    expect(find.byKey(const Key('event_inspector_blocked_hint')), findsOneWidget,
        reason: '空标题提示出现');
    expect(find.text('请填写标题后再保存'), findsOneWidget);
  });
}

extension _DraftCopy on CalendarEvent {
  CalendarEvent copy({String? id, String? calendarId, String? title}) =>
      CalendarEvent(
        id: id ?? this.id,
        remoteId: remoteId,
        calendarId: calendarId ?? this.calendarId,
        uid: uid,
        title: title ?? this.title,
        location: location,
        url: url,
        notes: notes,
        startAt: startAt,
        endAt: endAt,
        allDay: allDay,
        timeZone: timeZone,
        isFloating: isFloating,
        rrule: rrule,
        exdates: exdates,
        parentEventId: parentEventId,
        originalStartAt: originalStartAt,
        status: status,
        availability: availability,
        travelMinutes: travelMinutes,
        isPrivate: isPrivate,
        alerts: alerts,
        invitees: invitees,
        sequence: sequence,
        revision: revision,
        deletedAt: deletedAt,
        updatedAt: updatedAt,
      );
}

Calendar _cal(String id, String title) => Calendar(
      id: id,
      title: title,
      colorArgb: 0xFF007AFF,
      isVisible: true,
      isDefault: false,
    );

/// 可变假仓库（F-08）。
class _MutableRepo implements CalendarRepository {
  final List<CalendarEvent> upserted = [];
  final List<Calendar> calendars = [];
  final List<CalendarEvent> visible = [];
  final _eventController = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<CalendarEvent>> watchEvents(
      {required DateTime from, required DateTime to, Set<String>? calendarIds}) async* {
    yield List<CalendarEvent>.unmodifiable(visible);
    yield* _eventController.stream;
  }

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(calendars);
  }

  @override
  Future<String> upsertEvent(CalendarEvent e,
      {EditScope scope = EditScope.all, DateTime? occurrenceStart}) async {
    upserted.add(e);
    visible.add(e);
    _eventController.add(List<CalendarEvent>.unmodifiable(visible));
    return e.id;
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
    yield* const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
