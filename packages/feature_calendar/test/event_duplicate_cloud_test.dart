import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

/// #606 / 矩阵 D18 云端半边：原件已在服务端时，「复制」走 `/event/duplicate`，
/// 副本带着服务端返回的新编号落库（这样它既当场可见，也不会被
/// `_buildLocalMutations` 当成未上云的新事件再推一遍）。
void main() {
  Future<(_Repo, _CollabPort)> pump(
    WidgetTester tester, {
    required CalendarEvent event,
    required CalendarCollabPort? port,
  }) async {
    SharedPreferences.setMockInitialValues(const {});
    final repo = _Repo();
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
        kalenderEventsControllerProvider.overrideWithValue(
          kalender.DefaultEventsController(),
        ),
        calendarCollabPortProvider.overrideWithValue(port),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

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
    return (repo, port is _CollabPort ? port : _CollabPort());
  }

  CalendarEvent onServerEvent({String remoteId = '7'}) => CalendarEvent(
    id: 'e1',
    remoteId: remoteId,
    calendarId: 'c1',
    uid: 'u1',
    title: '周会',
    startAt: DateTime.utc(2026, 11, 3, 9),
    endAt: DateTime.utc(2026, 11, 3, 10),
    timeZone: 'Asia/Shanghai',
    updatedAt: DateTime.utc(2026, 11, 3),
  );

  testWidgets('原件有服务端编号 ⇒ 复制打服务端端点，副本落服务端新编号', (tester) async {
    final port = _CollabPort(returnedId: 99);
    final (repo, _) = await pump(
      tester,
      event: onServerEvent(),
      port: port,
    );

    await tester.tap(find.byKey(const Key('event_inspector_duplicate')));
    await tester.pumpAndSettle();

    expect(
      port.callId,
      7,
      reason: '要把 local→server 事件号（remoteId）解出来传给 /event/duplicate',
    );
    expect(port.callStartAt, DateTime.utc(2026, 11, 3, 9));
    expect(repo.events, hasLength(1));
    final copy = repo.events.single;
    expect(copy.id, isNot('e1'), reason: '副本必须是新的本地主记录');
    expect(copy.remoteId, '99', reason: '服务端已建副本，本地行要带上它的新编号');
    expect(copy.startAt, DateTime.utc(2026, 11, 3, 9));
  });

  testWidgets('服务端复制失败 ⇒ 不落副本、界面给出可见提示（不静默成功）', (tester) async {
    final port = _CollabPort(fail: true);
    final (repo, _) = await pump(tester, event: onServerEvent(), port: port);

    await tester.tap(find.byKey(const Key('event_inspector_duplicate')));
    await tester.pumpAndSettle();

    expect(
      repo.events,
      isEmpty,
      reason: '服务端没建成就不能先落本地副本，否则同步回来会变成两条',
    );
    expect(
      find.byKey(const Key('event_inspector_duplicate_error')),
      findsOneWidget,
      reason: '#618 的教训：裸 await 抛错时用户点了什么都没发生',
    );
  });

  testWidgets('未注入端口（纯本地档）⇒ 保持 #252 行为，副本不带 remoteId', (tester) async {
    final (repo, _) = await pump(tester, event: onServerEvent(), port: null);

    await tester.tap(find.byKey(const Key('event_inspector_duplicate')));
    await tester.pumpAndSettle();

    expect(repo.events, hasLength(1));
    expect(repo.events.single.remoteId, isNull);
  });

  testWidgets('原件还没上云（remoteId 为空）⇒ 先走本地复制，不发服务端请求', (tester) async {
    final port = _CollabPort(returnedId: 99);
    final (repo, _) = await pump(
      tester,
      event: onServerEvent(remoteId: ''),
      port: port,
    );

    await tester.tap(find.byKey(const Key('event_inspector_duplicate')));
    await tester.pumpAndSettle();

    expect(port.callId, isNull);
    expect(repo.events.single.remoteId, isNull);
  });
}

class _CollabPort implements CalendarCollabPort {
  _CollabPort({this.returnedId = 1, this.fail = false});

  final int returnedId;
  final bool fail;
  int? callId;
  DateTime? callStartAt;

  @override
  Future<int> duplicateEvent(int eventId, {required DateTime newStartAt}) async {
    callId = eventId;
    callStartAt = newStartAt;
    if (fail) {
      throw StateError('服务端拒绝');
    }
    return returnedId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements CalendarRepository {
  final List<CalendarEvent> events = [];

  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(const [
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

  @override
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    events.removeWhere((x) => x.id == e.id);
    events.add(e);
    return e.id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
