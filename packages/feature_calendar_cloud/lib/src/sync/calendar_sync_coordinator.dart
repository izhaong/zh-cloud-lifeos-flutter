// ignore_for_file: prefer_initializing_formals
/// 日历本地 ⇄ 云端协调器（F-17；契约 §3.9）。
///
/// 未登录跳过（TC-CAL-SYNC-101）；push 失败保留队列与原幂等键（TC-114）；
/// 401 不清本地数据（TC-115）；冲突按服务端 revision 重推，最多 3 次。
library;

import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';

import 'calendar_sync_models.dart';

class CalendarSyncReport {
  const CalendarSyncReport({
    this.pulled = 0,
    this.pushed = 0,
    this.conflicts = 0,
    this.skipped = false,
    this.unauthorized = false,
  });

  final int pulled;
  final int pushed;
  final int conflicts;
  final bool skipped;
  final bool unauthorized;
}

class CalendarSyncCoordinator {
  CalendarSyncCoordinator({
    required CalendarRepository repository,
    required CalendarSyncPort port,
    required SessionStore store,
    required String deviceId,
    DateTime Function()? clock,
  })  : _repository = repository,
        _port = port,
        _store = store,
        _deviceId = deviceId,
        _clock = clock ?? DateTime.now;

  static const int maxConflictRetries = 3;

  final CalendarRepository _repository;
  final CalendarSyncPort _port;
  final SessionStore _store;
  final String _deviceId;
  final DateTime Function() _clock;

  String? _cursor;

  /// 上次 push 失败保留的批次与幂等键（TC-114）。
  List<CalendarPushChange>? _pending;
  String? _pendingKey;

  Future<CalendarSyncReport> syncOnce() async {
    final session = await _store.read();
    if (session == null) {
      return const CalendarSyncReport(skipped: true);
    }
    var pulled = 0;
    try {
      final pull = await _port.pull(deviceId: _deviceId, cursor: _cursor);
      if (pull != null) {
        _cursor = pull.nextCursor ?? _cursor;
        pulled = await _applyPull(pull);
      }
    } on CalendarSyncException catch (e) {
      if (e.isUnauthorized) {
        return const CalendarSyncReport(unauthorized: true);
      }
      rethrow;
    }

    final batch = _pending ?? await _buildLocalMutations();
    if (batch.isEmpty) {
      return CalendarSyncReport(pulled: pulled);
    }
    final key =
        _pendingKey ?? 'cal-$_deviceId-${_clock().microsecondsSinceEpoch}';
    var current = batch;
    var conflicts = 0;
    try {
      for (var attempt = 0; attempt <= maxConflictRetries; attempt++) {
        final result = await _port.push(
          deviceId: _deviceId,
          idempotencyKey: key,
          changes: current,
        );
        if (result == null) {
          return CalendarSyncReport(pulled: pulled, skipped: true);
        }
        if (result.conflicts.isEmpty) {
          await _applyAccepted(current, result.accepted);
          _pending = null;
          _pendingKey = null;
          return CalendarSyncReport(
            pulled: pulled,
            pushed: result.accepted.length,
            conflicts: conflicts,
          );
        }
        conflicts = result.conflicts.length;
        if (attempt == maxConflictRetries) {
          break;
        }
        current = _retryConflicts(current, result.conflicts);
      }
      // 3 次仍冲突：留队列，下次换 revision 再试
      _pending = current;
      _pendingKey = key;
      return CalendarSyncReport(
          pulled: pulled, conflicts: conflicts);
    } on CalendarSyncException catch (e) {
      if (e.isUnauthorized) {
        return CalendarSyncReport(pulled: pulled, unauthorized: true);
      }
      _pending = current;
      _pendingKey = key;
      rethrow;
    } catch (_) {
      _pending = current;
      _pendingKey = key;
      rethrow;
    }
  }

  // ---- pull ----

  Future<int> _applyPull(CalendarPullResult pull) async {
    final calendars = await _repository.watchCalendars().first;
    final events = await _repository
        .watchEvents(from: DateTime.utc(1970), to: DateTime.utc(2100))
        .first;
    final calByRemote = {
      for (final c in calendars)
        if (c.remoteId != null) c.remoteId!: c,
    };
    final eventByRemote = {
      for (final e in events)
        if (e.remoteId != null) e.remoteId!: e,
    };
    var applied = 0;
    for (final change in [...pull.changes, ...pull.tombstones]) {
      final isDelete = change.operation.toUpperCase() == 'DELETE';
      switch (change.entityType) {
        case 'calendar':
          if (isDelete) {
            final local = calByRemote[change.entityId];
            if (local != null) {
              await _repository.deleteCalendar(local.id);
              applied++;
            }
          } else {
            final existing = calByRemote[change.entityId];
            final calendar = _calendarFrom(change, existing);
            await _repository.upsertCalendar(calendar);
            calByRemote[change.entityId] = calendar;
            applied++;
          }
        case 'event':
          if (isDelete) {
            final local = eventByRemote[change.entityId];
            if (local != null) {
              await _repository.deleteEvent(local.id);
              applied++;
            }
          } else {
            final existing = eventByRemote[change.entityId];
            final calendarId = _localCalendarId(
                change.payload['calendarId'], calByRemote, calendars);
            final event = _eventFrom(change, existing, calendarId);
            if (event != null) {
              await _repository.upsertEvent(event);
              eventByRemote[change.entityId] = event;
              applied++;
            }
          }
        case 'preference':
          if (!isDelete && change.payload.isNotEmpty) {
            final current = await _repository.watchPreference().first;
            await _repository.savePreference(_preferenceFrom(current, change.payload));
            applied++;
          }
      }
    }
    return applied;
  }

  Calendar _calendarFrom(CalendarPullChange change, Calendar? existing) {
    final payload = change.payload;
    return Calendar(
      id: existing?.id ?? 'srv-${change.entityId}',
      remoteId: change.entityId,
      title: payload['title']?.toString() ?? existing?.title ?? '日历',
      colorArgb: _parseColor(payload['color']?.toString()) ??
          existing?.colorArgb ??
          0xFF007AFF,
      kind: existing?.kind ?? CalendarKind.local,
      groupName: payload['groupName']?.toString() ?? existing?.groupName,
      isVisible: payload['isVisible'] is bool
          ? payload['isVisible'] as bool
          : (existing?.isVisible ?? true),
      isDefault: payload['isDefault'] is bool
          ? payload['isDefault'] as bool
          : (existing?.isDefault ?? false),
      ignoreAlerts: payload['ignoreAlerts'] is bool
          ? payload['ignoreAlerts'] as bool
          : (existing?.ignoreAlerts ?? false),
      lastRefreshError: existing?.lastRefreshError,
      revision: (payload['revision'] as num?)?.toInt() ??
          existing?.revision ??
          1,
    );
  }

  String _localCalendarId(dynamic serverCalendarId,
      Map<String, Calendar> calByRemote, List<Calendar> calendars) {
    final key = serverCalendarId?.toString();
    if (key != null) {
      final mapped = calByRemote[key];
      if (mapped != null) {
        return mapped.id;
      }
    }
    return calendars.isNotEmpty ? calendars.first.id : '';
  }

  CalendarEvent? _eventFrom(
      CalendarPullChange change, CalendarEvent? existing, String calendarId) {
    final payload = change.payload;
    final start = DateTime.tryParse(payload['startAt']?.toString() ?? '');
    final end = DateTime.tryParse(payload['endAt']?.toString() ?? '');
    if (start == null || end == null) {
      // S-14 旧 payload 只有 id/title（service #490 补全前无法重建）
      return null;
    }
    final alerts = <EventAlert>[
      for (final a in (payload['alerts'] as List? ?? const []))
        if (a is Map<String, dynamic>)
          EventAlert(
            offsetMinutes: (a['offsetMinutes'] as num?)?.toInt(),
            allDayOffsetDays: (a['allDayOffsetDays'] as num?)?.toInt(),
            allDayTime: a['allDayTime']?.toString(),
          ),
    ];
    return CalendarEvent(
      id: existing?.id ?? 'srv-${change.entityId}',
      remoteId: change.entityId,
      calendarId: calendarId,
      uid: payload['uid']?.toString() ?? existing?.uid ?? change.entityId,
      title: payload['title']?.toString() ?? existing?.title ?? '日程',
      location: payload['location']?.toString() ?? existing?.location,
      url: payload['url']?.toString() ?? existing?.url,
      notes: payload['notes']?.toString() ?? existing?.notes,
      startAt: start.toUtc(),
      endAt: end.toUtc(),
      allDay: payload['allDay'] == true ||
          (payload['allDay'] == null && (existing?.allDay ?? false)),
      timeZone: payload['timeZone']?.toString() ??
          existing?.timeZone ??
          'UTC',
      isFloating: payload['isFloating'] == true ||
          (payload['isFloating'] == null && (existing?.isFloating ?? false)),
      rrule: payload['rrule']?.toString() ?? existing?.rrule,
      exdates: existing?.exdates ?? const [],
      parentEventId: existing?.parentEventId,
      originalStartAt: existing?.originalStartAt,
      status: existing?.status ?? EventStatus.confirmed,
      availability: existing?.availability ?? EventAvailability.busy,
      travelMinutes: (payload['travelMinutes'] as num?)?.toInt() ??
          existing?.travelMinutes,
      isPrivate: payload['isPrivate'] == true ||
          (payload['isPrivate'] == null && (existing?.isPrivate ?? false)),
      alerts: alerts.isEmpty ? (existing?.alerts ?? const []) : alerts,
      invitees: existing?.invitees ?? const [],
      sequence: (payload['sequence'] as num?)?.toInt() ?? existing?.sequence ?? 0,
      revision: (payload['revision'] as num?)?.toInt() ??
          existing?.revision ??
          1,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  CalendarPreference _preferenceFrom(
      CalendarPreference current, Map<String, dynamic> payload) {
    int? asInt(String key) => (payload[key] as num?)?.toInt();
    bool? asBool(String key) =>
        payload[key] is bool ? payload[key] as bool : null;
    return copyCalendarPreference(
      current,
      startWeekOn: asInt('startWeekOn'),
      weekViewDays: asInt('weekViewDays'),
      dayStartHour: asInt('dayStartHour'),
      dayEndHour: asInt('dayEndHour'),
      hoursShown: asInt('hoursShown'),
      showDeclinedEvents: asBool('showDeclinedEvents'),
      timeZoneSupport: asBool('timeZoneSupport'),
      displayTimeZone: payload['displayTimeZone']?.toString(),
      defaultAlertTimedMinutes: asInt('defaultAlertTimedMinutes'),
      defaultAlertAllDayDays: asInt('defaultAlertAllDayDays'),
      defaultAlertAllDayTime: payload['defaultAlertAllDayTime']?.toString(),
      defaultDurationMinutes: asInt('defaultDurationMinutes'),
      showWeekNumbers: asBool('showWeekNumbers'),
      weekViewStartsToday: asBool('weekViewStartsToday'),
      showHolidays: asBool('showHolidays'),
      openEventsInWindow: asBool('openEventsInWindow'),
      revision: asInt('revision'),
    );
  }

  // ---- push ----

  Future<List<CalendarPushChange>> _buildLocalMutations() async {
    final calendars = await _repository.watchCalendars().first;
    final events = await _repository
        .watchEvents(from: DateTime.utc(1970), to: DateTime.utc(2100))
        .first;
    final mutations = <CalendarPushChange>[];
    for (final c in calendars.where(
        (c) => c.remoteId == null && c.kind == CalendarKind.local)) {
      mutations.add(CalendarPushChange(
        entityType: 'calendar',
        entityId: c.id,
        clientMutationId: c.id,
        clientUpdatedAt: DateTime.now().toUtc().toIso8601String(),
        payload: {'title': c.title, 'color': _colorHex(c.colorArgb)},
      ));
    }
    final calendarServerIds = {
      for (final c in calendars)
        if (c.remoteId != null) c.id: c.remoteId,
    };
    for (final e in events.where((e) => e.remoteId == null)) {
      final serverCalendarId = int.tryParse(calendarServerIds[e.calendarId] ?? '');
      if (serverCalendarId == null) {
        continue; // 日历先生成（下一轮再推事件）
      }
      mutations.add(CalendarPushChange(
        entityType: 'event',
        entityId: e.id,
        clientMutationId: e.id,
        clientUpdatedAt: e.updatedAt.toUtc().toIso8601String(),
        payload: {
          'uid': e.uid,
          'calendarId': serverCalendarId,
          'title': e.title,
          'location': e.location,
          'url': e.url,
          'notes': e.notes,
          'startAt': e.startAt.toUtc().toIso8601String(),
          'endAt': e.endAt.toUtc().toIso8601String(),
          'allDay': e.allDay,
          'timeZone': e.timeZone,
          'isFloating': e.isFloating,
          'rrule': e.rrule,
          'isPrivate': e.isPrivate,
          'alerts': [
            for (final a in e.alerts)
              {
                'offsetMinutes': a.offsetMinutes,
                'allDayOffsetDays': a.allDayOffsetDays,
                'allDayTime': a.allDayTime,
              },
          ],
        },
      ));
    }
    return mutations;
  }

  List<CalendarPushChange> _retryConflicts(
      List<CalendarPushChange> batch, List<CalendarConflict> conflicts) {
    final byMutation = {
      for (final c in conflicts)
        if (c.clientMutationId != null) c.clientMutationId!: c,
    };
    return [
      for (final change in batch)
        if (byMutation[change.clientMutationId] == null)
          change
        else
          CalendarPushChange(
            entityType: change.entityType,
            entityId: change.entityId,
            operation: change.operation,
            baseRevision: (byMutation[change.clientMutationId]!
                    .serverValue['revision'] as num?)
                ?.toInt(),
            payload: change.payload,
            clientMutationId: change.clientMutationId,
            clientUpdatedAt: change.clientUpdatedAt,
          ),
    ];
  }

  Future<void> _applyAccepted(
      List<CalendarPushChange> batch, List<CalendarAccepted> accepted) async {
    final acceptedById = {
      for (final a in accepted)
        if (a.clientMutationId != null) a.clientMutationId!: a,
    };
    for (final change in batch) {
      final hit = acceptedById[change.clientMutationId];
      if (hit == null || hit.entityId.isEmpty) {
        continue;
      }
      if (change.entityType == 'calendar') {
        final calendars = await _repository.watchCalendars().first;
        final existing = calendars.where((c) => c.id == change.entityId);
        if (existing.isNotEmpty) {
          final c = existing.first;
          await _repository.upsertCalendar(Calendar(
            id: c.id,
            remoteId: hit.entityId,
            title: c.title,
            colorArgb: c.colorArgb,
            kind: c.kind,
            groupName: c.groupName,
            isVisible: c.isVisible,
            isDefault: c.isDefault,
            sortOrder: c.sortOrder,
            ignoreAlerts: c.ignoreAlerts,
            sourceUrl: c.sourceUrl,
            refreshMinutes: c.refreshMinutes,
            holidayRegion: c.holidayRegion,
            lastRefreshError: c.lastRefreshError,
            permission: c.permission,
            revision: hit.revision ?? c.revision,
          ));
        }
      } else if (change.entityType == 'event') {
        final event = await _repository.getEvent(change.entityId);
        if (event != null) {
          await _repository.upsertEvent(
              _eventWithRemote(event, hit.entityId, hit.revision));
        }
      }
    }
  }

  static int? _parseColor(String? hex) {
    if (hex == null) {
      return null;
    }
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) {
      return null;
    }
    return 0xFF000000 | value;
  }

  static String _colorHex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}


CalendarEvent _eventWithRemote(
    CalendarEvent e, String remoteId, int? revision) {
  return CalendarEvent(
    id: e.id,
    remoteId: remoteId,
    calendarId: e.calendarId,
    uid: e.uid,
    title: e.title,
    location: e.location,
    url: e.url,
    notes: e.notes,
    startAt: e.startAt,
    endAt: e.endAt,
    allDay: e.allDay,
    timeZone: e.timeZone,
    isFloating: e.isFloating,
    rrule: e.rrule,
    exdates: e.exdates,
    parentEventId: e.parentEventId,
    originalStartAt: e.originalStartAt,
    status: e.status,
    availability: e.availability,
    travelMinutes: e.travelMinutes,
    isPrivate: e.isPrivate,
    alerts: e.alerts,
    invitees: e.invitees,
    sequence: e.sequence,
    revision: revision ?? e.revision,
    updatedAt: e.updatedAt,
  );
}
