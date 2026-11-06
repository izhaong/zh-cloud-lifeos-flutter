import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

/// #657 / 矩阵 F4 发送邀请（C-100）与 F5 移除受邀者（C-101）。
///
/// 此前 `CalendarCollabPort` 根本没有受邀者方法（kernel 侧只有 inboxList /
/// respondShare / calendarList / exportFeedUrl / importIcs / setDefaultCalendar /
/// exportCalendarIcs / exportAllIcs / duplicateEvent），矩阵两行却写「入口在受邀者
/// 面板里」⇒ 面板并不存在。本轮补端口 + 面板，并把这些行为钉成断言。
void main() {
  late _Port port;
  late ProviderContainer container;
  final controller = kalender.DefaultEventsController();

  CalendarEvent event({String? remoteId = '42'}) => CalendarEvent(
    id: 'e1',
    remoteId: remoteId,
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
    port = _Port();
    container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(_Repo()),
        sidebarPrefsProvider.overrideWith((ref) => null),
        kalenderEventsControllerProvider.overrideWithValue(controller),
        calendarCollabPortProvider.overrideWithValue(port),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpInspector(WidgetTester tester, CalendarEvent e) async {
    // 15 字段全展开需要 800×2400，与 TC-CAL-UI-132/219/221/222 同档。
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(
          Scaffold(
            body: EventInspectorPane(
              initialEvent: e,
              onSaved: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openInvitees(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('event_invitees_open')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('invitee_sheet')),
      findsOneWidget,
      reason: '面板没弹出来 ⇒ 后面的断言全会恒真',
    );
  }

  testWidgets('TC-CAL-UI-226 移除受邀者打到端口并按服务端真相重读', (tester) async {
    port.invitees = const [
      EventInvitee(memberUserId: '7', displayName: '阿良'),
      EventInvitee(memberUserId: '8', displayName: '阿静'),
    ];
    await pumpInspector(tester, event());
    await openInvitees(tester);

    expect(find.byKey(const Key('invitee_row_7')), findsOneWidget);
    expect(find.byKey(const Key('invitee_row_8')), findsOneWidget);

    await tester.tap(find.byKey(const Key('invitee_remove_7')));
    await tester.pumpAndSettle();

    expect(port.removed, [
      (42, '7'),
    ], reason: 'F5：必须按 (服务端日程编号, 成员编号) 调 /event/invitee/remove');
    expect(
      find.byKey(const Key('invitee_row_7')),
      findsNothing,
      reason: '移除后面板按 inviteeList 重读，该行不再存在',
    );
    expect(
      find.byKey(const Key('invitee_row_8')),
      findsOneWidget,
      reason: '只删点的那一条，旁侧受邀者不受影响',
    );
    expect(
      find.byKey(const Key('invitee_message')),
      findsOneWidget,
      reason: '写动作要有当场可见回执，不留「按了不知道成没成」',
    );
  });

  testWidgets('TC-CAL-UI-227 发送邀请按服务端编号调一次', (tester) async {
    port.invitees = const [EventInvitee(memberUserId: '7', displayName: '阿良')];
    await pumpInspector(tester, event());
    await openInvitees(tester);

    await tester.tap(find.byKey(const Key('invitee_send')));
    await tester.pumpAndSettle();

    expect(port.sent, [42], reason: 'F4：/event/invitee/send 只按当前日程编号发一次');
    expect(find.byKey(const Key('invitee_message')), findsOneWidget);
  });

  testWidgets('对照：草稿（无服务端编号）⇒ 不给进面板，只说「保存后可邀请」', (tester) async {
    await pumpInspector(tester, event(remoteId: null));

    expect(
      find.descendant(
        of: find.byKey(const Key('event_field_invitees')),
        matching: find.text('保存后可邀请'),
      ),
      findsOneWidget,
      reason: '受邀者读写都以服务端为准，草稿没有编号 ⇒ 要明确告知而不是静默禁用',
    );
    await tester.tap(find.byKey(const Key('event_invitees_open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invitee_sheet')), findsNothing);
    expect(port.listCalls, 0, reason: '草稿态不该打网络');
  });
}

class _Port implements CalendarCollabPort {
  List<EventInvitee> invitees = const [];
  final List<(int, String)> removed = [];
  final List<int> sent = [];
  int listCalls = 0;

  @override
  Future<List<EventInvitee>> inviteeList(int eventId) async {
    listCalls++;
    return invitees;
  }

  @override
  Future<void> removeInvitee(int eventId, String memberUserId) async {
    removed.add((eventId, memberUserId));
    invitees = [
      for (final i in invitees)
        if (i.memberUserId != memberUserId) i,
    ];
  }

  @override
  Future<void> sendInvitations(int eventId) async {
    sent.add(eventId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements CalendarRepository {
  final _eventController = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield const <CalendarEvent>[];
    yield* _eventController.stream;
  }

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield const <Calendar>[];
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
