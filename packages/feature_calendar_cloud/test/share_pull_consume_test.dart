// TC-CAL-SYNC-107／108（#365）：客户端 pull 必须**看见** share 变更。
//
// 由来：协调器 `_applyPull` 的 switch 只有 calendar / event / preference，
// 且**没有 default** —— 服务端（#553 已合并）现在会推 `entityType=share`，
// 客户端拉到了却静默丢弃：既不计入 applied，也没有任何信号让调用方去刷新影子日历。
import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_calendar_cloud/feature_calendar_cloud.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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

  test('TC-CAL-SYNC-107 pull 里的 share 变更不再被静默丢弃', () async {
    port.pullResults.add(const CalendarPullResult(
      changes: [
        CalendarPullChange(
          entityType: 'share',
          entityId: '555',
          operation: 'upsert',
          revision: 3,
          payload: {
            'calendarId': 100,
            'ownerUserId': 10,
            'memberUserId': 20,
            'permission': 'read',
            'state': 'accepted',
          },
        ),
      ],
      tombstones: [],
      nextCursor: 'c1',
    ));

    final report = await coordinator().syncOnce();

    expect(report.shareChanged, isTrue,
        reason: 'share 变更必须让调用方知道「共享关系变了」，否则影子日历永远不会刷新');
    expect(report.pulled, 1, reason: 'share 变更也要计入 applied');
    expect(repo.calendars, isEmpty,
        reason: 'share 不是可编辑实体，本地不应把它当成日历落库');
  });

  test('TC-CAL-SYNC-108 没有 share 时标记为 false（不误报）', () async {
    port.pullResults.add(const CalendarPullResult(
      changes: [
        CalendarPullChange(
          entityType: 'calendar',
          entityId: '100',
          operation: 'upsert',
          revision: 1,
          payload: {'title': '工作', 'color': '#007AFF'},
        ),
      ],
      tombstones: [],
      nextCursor: 'c2',
    ));

    final report = await coordinator().syncOnce();

    expect(report.shareChanged, isFalse);
    expect(repo.calendars, hasLength(1));
  });
}
