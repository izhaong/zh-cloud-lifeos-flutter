import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_calendar_cloud/feature_calendar_cloud.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

/// F-17 同步协调器（TC-CAL-SYNC-101/111～115；契约 §3.9）。
void main() {
  group('协调器', () {
    late _Repo repo;
    late _Port port;
    late _Store store;

    setUp(() {
      repo = _Repo();
      port = _Port();
      store = _Store();
    });

    CalendarSyncCoordinator coordinator() => CalendarSyncCoordinator(
          repository: repo,
          port: port,
          store: store,
          deviceId: 'dev-1',
          clock: () => DateTime.utc(2026, 10, 26, 12),
        );

    test('TC-CAL-SYNC-101 未登录跳过（无网络调用）', () async {
      store.session = null;
      final report = await coordinator().syncOnce();
      expect(report.skipped, isTrue);
      expect(port.pullCalls, 0);
      expect(port.pushCalls, 0);
    });

    test('TC-CAL-SYNC-111 登录后补拉/推送本地事件', () async {
      repo.calendars.add(const Calendar(
          id: 'srv-10',
          remoteId: '10',
          title: '工作',
          colorArgb: 0xFF007AFF));
      repo.events.add(_event(id: 'local-e1', calendarId: 'srv-10'));
      port.pushResults.add(const CalendarPushResult(accepted: [
        CalendarAccepted(
            clientMutationId: 'local-e1', entityId: '55', revision: 1),
      ]));

      final report = await coordinator().syncOnce();

      expect(report.pushed, 1);
      expect(port.lastPush!.changes.single.entityType, 'event');
      expect(port.lastPush!.changes.single.payload['title'], '周会');
      expect(repo.events.single.remoteId, '55', reason: '服务端 id 回填');
    });

    test('TC-CAL-SYNC-112 客户端只推 calendar/event/preference（不推 inbox）',
        () async {
      repo.calendars.add(const Calendar(
          id: 'srv-10',
          remoteId: '10',
          title: '工作',
          colorArgb: 0xFF007AFF));
      repo.events.add(_event(id: 'local-e1', calendarId: 'srv-10'));
      port.pushResults.add(const CalendarPushResult());

      await coordinator().syncOnce();

      final types =
          port.lastPush!.changes.map((c) => c.entityType).toSet();
      expect(types.difference({'calendar', 'event', 'preference'}), isEmpty);
      expect(types.contains('inbox'), isFalse);
    });

    test('TC-CAL-SYNC-113 偏好 pull → 本地 startWeekOn 变化', () async {
      port.pullResults.add(const CalendarPullResult(changes: [
        CalendarPullChange(
          entityType: 'preference',
          entityId: '1',
          operation: 'UPSERT',
          payload: {'startWeekOn': 7, 'weekViewDays': 5, 'revision': 3},
        ),
      ], tombstones: []));

      await coordinator().syncOnce();

      expect(repo.preference.startWeekOn, 7);
      expect(repo.preference.weekViewDays, 5);
    });

    // TC-CAL-UI-125（同步 pull 半）：日历合并重建不得把订阅刷新失败标记写空
    test('TC-CAL-UI-125 pull 合并保留 lastRefreshError', () async {
      repo.calendars.add(const Calendar(
          id: 'srv-10',
          remoteId: '10',
          title: '失败订阅',
          colorArgb: 0xFFAF52DE,
          kind: CalendarKind.subscription,
          lastRefreshError: '拉取超时'));
      port.pullResults.add(const CalendarPullResult(changes: [
        CalendarPullChange(
          entityType: 'calendar',
          entityId: '10',
          operation: 'UPSERT',
          payload: {'title': '改名的订阅', 'revision': 4},
        ),
      ], tombstones: []));

      await coordinator().syncOnce();

      final merged = repo.calendars.singleWhere((c) => c.id == 'srv-10');
      expect(merged.title, '改名的订阅');
      expect(merged.lastRefreshError, '拉取超时',
          reason: '全量 upsert 不能把刷新失败写成 NULL');
    });

    // TC-CAL-UI-125（同步 push 半）：接受结果写回 remoteId 时保留刷新失败标记
    // （防御性：push 只筛 kind=local 的日历，订阅行本不进这条分支）
    test('TC-CAL-UI-125 push 接受后保留 lastRefreshError', () async {
      repo.calendars.add(const Calendar(
          id: 'local-c1',
          title: '本地日历',
          colorArgb: 0xFF007AFF,
          lastRefreshError: '拉取超时'));
      port.pushResults.add(const CalendarPushResult(accepted: [
        CalendarAccepted(
            clientMutationId: 'local-c1', entityId: '77', revision: 2),
      ]));

      await coordinator().syncOnce();

      final pushed = repo.calendars.singleWhere((c) => c.id == 'local-c1');
      expect(pushed.remoteId, '77');
      expect(pushed.lastRefreshError, '拉取超时',
          reason: '接受写回不得清掉刷新失败标记');
    });

    test('TC-CAL-SYNC-114 首次 push 失败保留队列与幂等键', () async {
      repo.calendars.add(const Calendar(
          id: 'srv-10',
          remoteId: '10',
          title: '工作',
          colorArgb: 0xFF007AFF));
      repo.events.add(_event(id: 'local-e1', calendarId: 'srv-10'));
      port.pushError = CalendarSyncException('timeout');
      final c = coordinator();
      await expectLater(c.syncOnce(), throwsA(isA<CalendarSyncException>()));

      port.pushError = null;
      port.pushResults.add(const CalendarPushResult(accepted: [
        CalendarAccepted(
            clientMutationId: 'local-e1', entityId: '55', revision: 1),
      ]));
      await c.syncOnce();

      expect(port.pushKeys.length, 2);
      expect(port.pushKeys[0], port.pushKeys[1], reason: '幂等键不变');
      expect(repo.events.single.remoteId, '55');
    });

    test('TC-CAL-SYNC-115 token 过期 401 不清本地数据', () async {
      repo.events.add(_event(id: 'local-e1', calendarId: 'srv-10'));
      port.pullError = CalendarSyncException('401', statusCode: 401);

      final report = await coordinator().syncOnce();

      expect(report.unauthorized, isTrue);
      expect(repo.events.length, 1, reason: '本地数据仍在');
      expect(repo.events.single.title, '周会');
      expect(port.pushCalls, 0);
    });

    test('TC-CAL-SYNC-108 pull tombstone → 本地删除（事件与日历）', () async {
      repo.calendars.add(const Calendar(
          id: 'srv-10',
          remoteId: '10',
          title: '工作',
          colorArgb: 0xFF007AFF));
      repo.events
          .add(_event(id: 'srv-55', calendarId: 'srv-10', remoteId: '55'));
      port.pullResults.add(const CalendarPullResult(changes: [], tombstones: [
        CalendarPullChange(
            entityType: 'event',
            entityId: '55',
            operation: 'DELETE',
            payload: {}),
        CalendarPullChange(
            entityType: 'calendar',
            entityId: '10',
            operation: 'DELETE',
            payload: {}),
      ]));

      await coordinator().syncOnce();

      expect(repo.events, isEmpty, reason: '对端删除事件后本地按 remoteId 命中并删除');
      expect(repo.calendars, isEmpty);
    });

    test('pull 富快照 → 重建事件时间/时区/提醒', () async {
      port.pullResults.add(const CalendarPullResult(changes: [
        CalendarPullChange(
          entityType: 'calendar',
          entityId: '10',
          operation: 'UPSERT',
          payload: {'title': '工作', 'color': '#FF3B30'},
        ),
        CalendarPullChange(
          entityType: 'event',
          entityId: '55',
          operation: 'UPSERT',
          payload: {
            'uid': 'u55',
            'calendarId': 10,
            'title': '评审',
            'startAt': '2026-10-27T02:00:00Z',
            'endAt': '2026-10-27T03:00:00Z',
            'allDay': false,
            'timeZone': 'Asia/Shanghai',
            'alerts': [
              {'offsetMinutes': -15},
            ],
          },
        ),
      ], tombstones: []));

      await coordinator().syncOnce();

      final event = repo.events.singleWhere((e) => e.remoteId == '55');
      expect(event.title, '评审');
      expect(event.startAt, DateTime.utc(2026, 10, 27, 2));
      expect(event.timeZone, 'Asia/Shanghai');
      expect(event.alerts.single.offsetMinutes, -15);
      expect(event.calendarId, 'srv-10');
    });
  });
}

CalendarEvent _event(
        {required String id,
        required String calendarId,
        String? remoteId}) =>
    CalendarEvent(
      id: id,
      remoteId: remoteId,
      calendarId: calendarId,
      uid: 'u-$id',
      title: '周会',
      startAt: DateTime.utc(2026, 10, 26, 2),
      endAt: DateTime.utc(2026, 10, 26, 3),
      timeZone: 'UTC',
      updatedAt: DateTime.utc(2026, 10, 26, 1),
    );

class _Store implements SessionStore {
  MemberSession? session = const MemberSession(
      userId: '1', tenantId: '1', accessToken: 'token');

  @override
  Future<MemberSession?> read() async => session;

  @override
  Future<void> write(MemberSession s) async => session = s;

  @override
  Future<void> clear() async => session = null;
}

class _PushCall {
  _PushCall(this.idempotencyKey, this.changes);
  final String idempotencyKey;
  final List<CalendarPushChange> changes;
}

class _Port implements CalendarSyncPort {
  int pullCalls = 0;
  int pushCalls = 0;
  CalendarSyncException? pullError;
  CalendarSyncException? pushError;
  final List<CalendarPullResult> pullResults = [];
  final List<CalendarPushResult> pushResults = [];
  final List<String> pushKeys = [];
  _PushCall? lastPush;

  @override
  Future<CalendarPullResult?> pull(
      {required String deviceId, String? cursor, int limit = 200}) async {
    pullCalls++;
    if (pullError != null) {
      throw pullError!;
    }
    return pullResults.isEmpty ? null : pullResults.removeAt(0);
  }

  @override
  Future<CalendarPushResult?> push({
    required String deviceId,
    required String idempotencyKey,
    required List<CalendarPushChange> changes,
  }) async {
    pushCalls++;
    pushKeys.add(idempotencyKey);
    lastPush = _PushCall(idempotencyKey, changes);
    if (pushError != null) {
      throw pushError!;
    }
    return pushResults.isEmpty
        ? const CalendarPushResult()
        : pushResults.removeAt(0);
  }
}

class _Repo implements CalendarRepository {
  final List<Calendar> calendars = [];
  final List<CalendarEvent> events = [];
  CalendarPreference preference = const CalendarPreference();
  final _calendars = StreamController<List<Calendar>>.broadcast();
  final _events = StreamController<List<CalendarEvent>>.broadcast();
  final _prefs = StreamController<CalendarPreference>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(calendars);
    yield* _calendars.stream;
  }

  @override
  Stream<List<CalendarEvent>> watchEvents(
      {required DateTime from,
      required DateTime to,
      Set<String>? calendarIds}) async* {
    yield List<CalendarEvent>.unmodifiable(events);
    yield* _events.stream;
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield preference;
    yield* _prefs.stream;
  }

  @override
  Future<CalendarEvent?> getEvent(String id) async {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<void> upsertCalendar(Calendar c) async {
    calendars.removeWhere((x) => x.id == c.id);
    calendars.add(c);
    _calendars.add(List<Calendar>.unmodifiable(calendars));
  }

  @override
  Future<String> upsertEvent(CalendarEvent e,
      {EditScope scope = EditScope.all, DateTime? occurrenceStart}) async {
    events.removeWhere((x) => x.id == e.id);
    events.add(e);
    _events.add(List<CalendarEvent>.unmodifiable(events));
    return e.id;
  }

  @override
  Future<void> deleteEvent(String id,
      {EditScope scope = EditScope.all, DateTime? occurrenceStart}) async {
    events.removeWhere((x) => x.id == id);
  }

  @override
  Future<void> deleteCalendar(String id) async {
    calendars.removeWhere((x) => x.id == id);
  }

  @override
  Future<void> savePreference(CalendarPreference p) async {
    preference = p;
    _prefs.add(p);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
