import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

/// #252 / 矩阵 D18：复制日程（Apple 编辑 ▸ 复制）。
void main() {
  group('duplicateEventCopy', () {
    final source = CalendarEvent(
      id: 'e1',
      remoteId: 'srv-1',
      calendarId: 'c1',
      uid: 'u1',
      title: '周会',
      location: '会议室',
      url: 'https://example.com/e',
      notes: '备注',
      startAt: DateTime.utc(2026, 10, 24, 10),
      endAt: DateTime.utc(2026, 10, 24, 11),
      timeZone: 'Asia/Shanghai',
      rrule: 'FREQ=WEEKLY',
      exdates: [DateTime.utc(2026, 10, 31, 10)],
      parentEventId: 'master-1',
      originalStartAt: DateTime.utc(2026, 10, 24, 10),
      travelMinutes: 15,
      isPrivate: true,
      sequence: 4,
      revision: 7,
      updatedAt: DateTime.utc(2026, 10, 24),
    );

    test('字段与原件一致（时间/重复/提醒/日历/私密）', () {
      final copy = duplicateEventCopy(source, 'e2');
      expect(copy.calendarId, 'c1');
      expect(copy.title, '周会');
      expect(copy.location, '会议室');
      expect(copy.url, 'https://example.com/e');
      expect(copy.notes, '备注');
      expect(copy.startAt, source.startAt);
      expect(copy.endAt, source.endAt);
      expect(copy.timeZone, 'Asia/Shanghai');
      expect(copy.rrule, 'FREQ=WEEKLY');
      expect(copy.travelMinutes, 15);
      expect(copy.isPrivate, isTrue);
    });

    test('副本是新主记录：换 id/uid、清例外与排除、sequence/revision 归位', () {
      final copy = duplicateEventCopy(source, 'e2');
      expect(copy.id, 'e2');
      expect(copy.uid, 'e2', reason: '副本不能复用原件 uid');
      expect(copy.remoteId, isNull, reason: '副本尚未上云，不能带原件服务端 id');
      expect(copy.exdates, isEmpty, reason: '例外日期属于原件，不能继承');
      expect(copy.parentEventId, isNull, reason: '副本不是任何重复记录的例外');
      expect(copy.originalStartAt, isNull);
      expect(copy.sequence, 0);
      expect(copy.revision, 1);
    });
  });

  testWidgets('Inspector 点「复制」→ 库中多一条同字段事件', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final repo = _Repo();
    final controller = kalender.DefaultEventsController();
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
        kalenderEventsControllerProvider.overrideWithValue(controller),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final event = CalendarEvent(
      id: 'e1',
      calendarId: 'c1',
      uid: 'u1',
      title: '周会',
      startAt: DateTime.utc(2026, 10, 24, 10),
      endAt: DateTime.utc(2026, 10, 24, 11),
      timeZone: 'UTC',
      updatedAt: DateTime.utc(2026, 10, 24),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(
          Scaffold(
            body: EventInspectorPane(
              initialEvent: event,
              onSaved: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('event_inspector_duplicate')), findsOneWidget,
        reason: '既有日程要有复制入口（新建草稿才隐藏）');
    await tester.tap(find.byKey(const Key('event_inspector_duplicate')));
    await tester.pumpAndSettle();

    // 仓库初始为空（原件只是 inspector 的入参），复制应恰好落一条副本
    expect(repo.events, hasLength(1), reason: '复制应落一条副本');
    final copy = repo.events.single;
    expect(copy.id, isNot('e1'));
    expect(copy.title, '周会');
    expect(copy.startAt, event.startAt);
    expect(copy.uid, copy.id);
  });

  testWidgets('重复日程复制后保存按整条处理（不再问作用域，不误改原系列）', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final repo = _Repo();
    final controller = kalender.DefaultEventsController();
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
        kalenderEventsControllerProvider.overrideWithValue(controller),
      ],
    );
    addTearDown(container.dispose);

    final occurrenceStart = DateTime.utc(2026, 10, 24, 10);
    final recurring = CalendarEvent(
      id: 'e1',
      calendarId: 'c1',
      uid: 'u1',
      title: '每周例会',
      startAt: occurrenceStart,
      endAt: DateTime.utc(2026, 10, 24, 11),
      timeZone: 'UTC',
      rrule: 'FREQ=WEEKLY',
      updatedAt: DateTime.utc(2026, 10, 24),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(
          Scaffold(
            body: EventInspectorPane(
              initialEvent: recurring,
              occurrenceStart: occurrenceStart,
              onSaved: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('event_inspector_duplicate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event_inspector_save')));
    await tester.pumpAndSettle();

    expect(
      find.text('编辑重复日程'),
      findsNothing,
      reason: '复制出来的副本是独立记录，不该再问 THIS/FUTURE 作用域',
    );
    expect(repo.lastScope, EditScope.all, reason: '副本按整条保存');
    expect(repo.lastOccurrenceStart, isNull,
        reason: '不能把原件的 occurrenceStart 带到副本上（会改坏原系列）');
  });

  testWidgets('复制后切换到另一条重复日程 → 作用域语义恢复（不残留独立标记）', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final repo = _Repo();
    final controller = kalender.DefaultEventsController();
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
        kalenderEventsControllerProvider.overrideWithValue(controller),
      ],
    );
    addTearDown(container.dispose);

    final occurrenceStart = DateTime.utc(2026, 10, 24, 10);
    CalendarEvent recurring(String id, String title) => CalendarEvent(
      id: id,
      calendarId: 'c1',
      uid: id,
      title: title,
      startAt: occurrenceStart,
      endAt: DateTime.utc(2026, 10, 24, 11),
      timeZone: 'UTC',
      rrule: 'FREQ=WEEKLY',
      updatedAt: DateTime.utc(2026, 10, 24),
    );

    Widget pane(CalendarEvent e) => UncontrolledProviderScope(
      container: container,
      child: lifeTestHost(
        Scaffold(
          body: EventInspectorPane(
            initialEvent: e,
            occurrenceStart: occurrenceStart,
            onSaved: () {},
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(pane(recurring('e1', '例会一')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event_inspector_duplicate')));
    await tester.pumpAndSettle();

    // 换选另一条重复日程（expanded 第三栏会复用同一个 pane 实例）
    await tester.pumpWidget(pane(recurring('e2', '例会二')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event_inspector_save')));
    await tester.pumpAndSettle();

    expect(
      find.text('编辑重复日程'),
      findsOneWidget,
      reason: '换选后的重复日程必须重新询问 THIS/FUTURE（独立副本标记已清）',
    );
  });
}

class _Repo implements CalendarRepository {
  final List<CalendarEvent> events = [];

  @override
  Stream<List<Calendar>> watchCalendars() =>
      Stream.value(const [
        Calendar(id: 'c1', title: '个人', colorArgb: 0xFF007AFF),
      ]);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) => Stream.value(List<CalendarEvent>.unmodifiable(events));

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(const CalendarPreference());

  /// 最近一次 upsert 的作用域参数（#252 审查：独立副本不能再走 THIS/FUTURE）。
  EditScope? lastScope;
  DateTime? lastOccurrenceStart;

  @override
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    lastScope = scope;
    lastOccurrenceStart = occurrenceStart;
    events.removeWhere((x) => x.id == e.id);
    events.add(e);
    return e.id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
