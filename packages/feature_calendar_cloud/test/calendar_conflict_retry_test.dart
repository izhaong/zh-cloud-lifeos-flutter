import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_calendar_cloud/feature_calendar_cloud.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

/// #607 档 A：TC-CAL-SYNC-107「客户端冲突重推」从 `手动` 换成可执行断言。
///
/// 台账原文把预期写成「冲突后 `clientUpdatedAt` 更新，带新 revision 重推」，
/// 前半句与契约不符：契约 §3.9（docs `lifeos/calendar/design/…domain-contract.md:322`）
/// 与备忘录侧同族条款（`lifeos/note/design/…:83`）说的是
/// **服务端**拿 `clientUpdatedAt` 做 LWW 比较（较新才整条覆盖，更旧回 `1_070_220`）。
/// `clientUpdatedAt` 是「这条本地编辑发生的时间戳」，重推时同一条编辑不该改它，
/// 该换的是 `baseRevision`（换成冲突回执里服务端当前 revision）。
/// 这里把两条都钉住：重推确实换了 revision，且确实**没有**偷偷 bump 时间戳
/// （否则任何冲突都会自动判成本地更新，把服务端的 LWW 变成摆设）。
void main() {
  late _Repo repo;
  late _ScriptedPort port;
  late _Store store;

  setUp(() {
    repo = _Repo();
    port = _ScriptedPort();
    store = _Store();
    // 一条远端日历 + 一条纯本地事件 ⇒ 本轮只会有一个 change，便于数推送次数。
    repo.calendars.add(
      const Calendar(
        id: 'srv-10',
        remoteId: '10',
        title: '工作',
        colorArgb: 0xFF007AFF,
      ),
    );
    repo.events.add(
      CalendarEvent(
        id: 'local-e1',
        calendarId: 'srv-10',
        uid: 'u-local-e1',
        title: '周会',
        startAt: DateTime.utc(2026, 10, 26, 2),
        endAt: DateTime.utc(2026, 10, 26, 3),
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 10, 26, 1),
      ),
    );
  });

  CalendarSyncCoordinator coordinator() => CalendarSyncCoordinator(
    repository: repo,
    port: port,
    store: store,
    deviceId: 'dev-1',
    clock: () => DateTime.utc(2026, 10, 26, 12),
  );

  CalendarConflict conflictOf({int serverRevision = 7}) => CalendarConflict(
    clientMutationId: 'local-e1',
    reason: 'REVISION_CONFLICT',
    serverValue: {'revision': serverRevision},
    clientValue: const {'revision': 3},
  );

  test('上界是声明出来的，不是循环里数出来的', () {
    expect(CalendarSyncCoordinator.maxConflictRetries, 3);
  });

  test('TC-CAL-SYNC-107 冲突一次 ⇒ 换新 baseRevision 重推并成功，clientUpdatedAt 不变', () async {
    port.script = [
      CalendarPushResult(conflicts: [conflictOf(serverRevision: 7)]),
      const CalendarPushResult(
        accepted: [
          CalendarAccepted(
            clientMutationId: 'local-e1',
            entityId: '55',
            revision: 8,
          ),
        ],
      ),
    ];

    final report = await coordinator().syncOnce();

    expect(port.pushBatches, hasLength(2), reason: '一次冲突 ⇒ 共两次 push');
    expect(report.pushed, 1);
    expect(report.conflicts, 1);
    final first = port.pushBatches[0].single;
    final retry = port.pushBatches[1].single;
    expect(
      retry.baseRevision,
      7,
      reason: '重推必须带冲突回执里服务端的 revision，不然第二次还是撞同一个 revision',
    );
    expect(
      retry.clientUpdatedAt,
      first.clientUpdatedAt,
      reason:
          '`clientUpdatedAt` 是这条编辑的 LWW 戳，重推同一条不该改它；'
          '改了就等于任何冲突都自动判本地更新，把契约 §3.9 的「更旧则 1_070_220」架空',
    );
    expect(retry.payload['title'], first.payload['title']);
    expect(repo.events.single.remoteId, '55', reason: '成功后回填服务端 id');
  });

  test('TC-CAL-SYNC-107 一直冲突 ⇒ 最多 1+3 次 push，之后停下并留住队列', () async {
    port.script = null; // 脚本耗尽后按 alwaysConflict 继续回冲突
    port.alwaysConflict = () => CalendarPushResult(
      conflicts: [conflictOf(serverRevision: 7)],
    );

    final report = await coordinator().syncOnce();

    expect(
      port.pushBatches,
      hasLength(CalendarSyncCoordinator.maxConflictRetries + 1),
      reason: '初次 + 3 次重试 = 4 次；第 5 次不许再发（失控推送正是本条要挡的）',
    );
    expect(report.pushed, 0);
    expect(report.conflicts, 1);
    expect(
      port.pushKeys.toSet(),
      hasLength(1),
      reason: '同一批重推复用同一幂等键（与 TC-CAL-SYNC-114 同口径）',
    );

    // 留住的证据要能自己站住：①本地那条仍未回填服务端 id（= 没被当成已同步丢掉），
    // ②换一个新的协调器实例再同步，它仍被 `_buildLocalMutations` 重新挑出来推送。
    // （实例内的 `_pending` 队列跨实例不可见，所以这里判的是「数据侧没丢」，
    // 而不是「内存里那份队列还在」——别把两者混成一条断言。）
    expect(
      repo.events.single.remoteId,
      isNull,
      reason: '冲突到上界后不许把本地编辑标成已同步（否则编辑静默丢失）',
    );
    port.pushBatches.clear();
    await CalendarSyncCoordinator(
      repository: repo,
      port: port,
      store: store,
      deviceId: 'dev-1',
      clock: () => DateTime.utc(2026, 10, 26, 12),
    ).syncOnce();
    expect(
      port.pushBatches.first.single.entityId,
      'local-e1',
      reason: '下一轮还要再推这条，而不是就此停下',
    );
  });

  test('反向对照：无冲突时一次就过，不做多余重推', () async {
    port.script = const [
      CalendarPushResult(
        accepted: [
          CalendarAccepted(
            clientMutationId: 'local-e1',
            entityId: '60',
            revision: 1,
          ),
        ],
      ),
    ];

    final report = await coordinator().syncOnce();

    expect(port.pushBatches, hasLength(1));
    expect(report.pushed, 1);
    expect(report.conflicts, 0);
  });
}

class _Store implements SessionStore {
  MemberSession? session = const MemberSession(
    userId: '1',
    tenantId: '1',
    accessToken: 'token',
  );

  @override
  Future<MemberSession?> read() async => session;

  @override
  Future<void> write(MemberSession s) async => session = s;

  @override
  Future<void> clear() async => session = null;
}

/// 记录每一次 push 的完整批次（现有 `_Port` 只留 lastPush，数不出重试次数）。
class _ScriptedPort implements CalendarSyncPort {
  List<CalendarPushResult>? script;
  CalendarPushResult Function()? alwaysConflict;
  final List<List<CalendarPushChange>> pushBatches = [];
  final List<String> pushKeys = [];
  int _scriptIndex = 0;

  @override
  Future<CalendarPullResult?> pull({
    required String deviceId,
    String? cursor,
    int limit = 200,
  }) async => null;

  @override
  Future<CalendarPushResult?> push({
    required String deviceId,
    required String idempotencyKey,
    required List<CalendarPushChange> changes,
  }) async {
    pushKeys.add(idempotencyKey);
    pushBatches.add(List<CalendarPushChange>.of(changes));
    final results = script;
    // 按下标取，不用 removeAt：脚本表常写成 `const [...]`，
    // 对不可变列表调 removeAt 会抛 Unsupported operation（这条我自己踩过一次）。
    if (results != null && _scriptIndex < results.length) {
      return results[_scriptIndex++];
    }
    return alwaysConflict?.call() ?? const CalendarPushResult();
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
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield List<CalendarEvent>.unmodifiable(events);
    yield* _events.stream;
  }

  @override
  Stream<CalendarPreference> watchPreference() => Stream.value(preference);

  @override
  Future<CalendarEvent?> getEvent(String id) async {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<void> upsertCalendar(Calendar c) async {
    calendars
      ..removeWhere((x) => x.id == c.id)
      ..add(c);
    _calendars.add(List<Calendar>.unmodifiable(calendars));
  }

  @override
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    events
      ..removeWhere((x) => x.id == e.id)
      ..add(e);
    _events.add(List<CalendarEvent>.unmodifiable(events));
    return e.id;
  }

  @override
  Future<void> deleteEvent(
    String id, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
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
