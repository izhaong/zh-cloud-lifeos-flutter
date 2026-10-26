import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart'
    show
        BooleanExpressionOperators,
        ComparableExpr,
        OrderingTerm,
        StringExpressionOperators,
        Value;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;

import 'db.dart' as db;

/// [kernel.CalendarRepository] 的 Drift 实现（离线持久化，契约 §5.3）。
///
/// - `watch*` 基于 drift 响应式 watch 流，写操作自动推送新快照
/// - 时间契约：startAt/endAt 等一律 UTC（读回时 toUtc 归一，实例相等不受
///   drift 本地化读取影响）；exdates/alerts/invitees 走 JSON 文本列
/// - 重复事件编辑语义照抄契约 §3.2.1：THIS→例外行+exdates、
///   FUTURE→主记录 UNTIL(occurrenceStart-1s)+新主记录、ALL→直改+例外平移
class DriftCalendarRepository implements kernel.CalendarRepository {
  DriftCalendarRepository(this._db);

  final db.LifeProductivityDb _db;

  /// 测试注入「当前时间」。
  DateTime? nowForTest;

  DateTime get _now => nowForTest ?? DateTime.now();

  /// 本地单用户偏好行主键（未登录 F1 Noop 口径）。
  static const String _localUserKey = 'local';

  @override
  Stream<List<kernel.Calendar>> watchCalendars() {
    final query = _db.select(_db.calendars)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.id),
      ]);
    return query.watch().map(
          (rows) => List<kernel.Calendar>.unmodifiable(rows.map(_calendarModel)),
        );
  }

  @override
  Stream<List<kernel.CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) {
    final query = _db.select(_db.calendarEvents)
      ..where((t) => t.deletedAt.isNull())
      // 契约 §2.2 range 口径：主记录 start < to；单次/例外须与窗口相交，
      // 重复主记录不按窗口截断（展开交给 expandOccurrences 过滤）
      ..where((t) => t.startAt.isSmallerThanValue(to))
      ..where((t) =>
          (t.rrule.isNull() & t.endAt.isBiggerThanValue(from)) |
          t.rrule.isNotNull());
    if (calendarIds != null && calendarIds.isNotEmpty) {
      query.where((t) => t.calendarId.isIn(calendarIds));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.startAt),
      (t) => OrderingTerm(expression: t.id),
    ]);
    return query.watch().map(
          (rows) =>
              List<kernel.CalendarEvent>.unmodifiable(rows.map(_eventModel)),
        );
  }

  @override
  Future<kernel.CalendarEvent?> getEvent(String id) async {
    final row = await (_db.select(_db.calendarEvents)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _eventModel(row);
  }

  @override
  Future<void> upsertCalendar(kernel.Calendar c) async {
    await _db.into(_db.calendars).insertOnConflictUpdate(
          db.CalendarsCompanion.insert(
            id: c.id,
            remoteId: Value(c.remoteId),
            title: c.title,
            colorArgb: c.colorArgb,
            kind: Value(c.kind.id),
            groupName: Value(c.groupName),
            isVisible: Value(c.isVisible),
            isDefault: Value(c.isDefault),
            sortOrder: Value(c.sortOrder),
            ignoreAlerts: Value(c.ignoreAlerts),
            sourceUrl: Value(c.sourceUrl),
            refreshMinutes: Value(c.refreshMinutes),
            holidayRegion: Value(c.holidayRegion),
            lastRefreshError: Value(c.lastRefreshError),
            permission: Value(c.permission.id),
            revision: Value(c.revision),
            deletedAt: Value(c.deletedAt),
          ),
        );
  }

  @override
  Future<void> deleteCalendar(String id) async {
    await _db.transaction(() async {
      final target = await (_db.select(_db.calendars)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (target == null) return;
      if (target.kind == kernel.CalendarKind.local.id) {
        // 契约 §7 1_070_104：至少保留一个本地日历（只数在用 LOCAL）
        final locals = await (_db.select(_db.calendars)
              ..where((t) =>
                  t.kind.equals(kernel.CalendarKind.local.id) &
                  t.deletedAt.isNull()))
            .get();
        if (locals.length <= 1) {
          throw StateError('至少保留一个本地日历');
        }
      }
      // 日历软删，其日程级联软删
      await (_db.update(_db.calendars)..where((t) => t.id.equals(id)))
          .write(db.CalendarsCompanion(deletedAt: Value(_now)));
      await (_db.update(_db.calendarEvents)
            ..where((t) => t.calendarId.equals(id)))
          .write(db.CalendarEventsCompanion(deletedAt: Value(_now)));
    });
  }

  @override
  Future<void> setDefaultCalendar(String id) async {
    await _db.transaction(() async {
      await (_db.update(_db.calendars)..where((t) => t.deletedAt.isNull()))
          .write(const db.CalendarsCompanion(isDefault: Value(false)));
      await (_db.update(_db.calendars)..where((t) => t.id.equals(id)))
          .write(const db.CalendarsCompanion(isDefault: Value(true)));
    });
  }

  @override
  Future<void> reorderCalendars(List<String> ids) async {
    await _db.transaction(() async {
      for (var i = 0; i < ids.length; i++) {
        await (_db.update(_db.calendars)..where((t) => t.id.equals(ids[i])))
            .write(db.CalendarsCompanion(sortOrder: Value(i)));
      }
    });
  }

  @override
  Future<void> setVisibility({
    String? id,
    bool? visible,
    bool? allVisible,
    String? onlyId,
  }) async {
    await _db.transaction(() async {
      if (onlyId != null) {
        // 仅显示该日历：其余全部勾掉
        await (_db.update(_db.calendars)..where((t) => t.deletedAt.isNull()))
            .write(const db.CalendarsCompanion(isVisible: Value(false)));
        await (_db.update(_db.calendars)..where((t) => t.id.equals(onlyId)))
            .write(const db.CalendarsCompanion(isVisible: Value(true)));
        return;
      }
      if (allVisible != null) {
        await (_db.update(_db.calendars)..where((t) => t.deletedAt.isNull()))
            .write(db.CalendarsCompanion(isVisible: Value(allVisible)));
        return;
      }
      if (id != null && visible != null) {
        await (_db.update(_db.calendars)..where((t) => t.id.equals(id)))
            .write(db.CalendarsCompanion(isVisible: Value(visible)));
      }
    });
  }

  @override
  Future<String> upsertEvent(
    kernel.CalendarEvent e, {
    kernel.EditScope scope = kernel.EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    await _assertWritable(e.calendarId);
    final existing = await (_db.select(_db.calendarEvents)
          ..where((t) => t.id.equals(e.id)))
        .getSingleOrNull();

    if (scope == kernel.EditScope.thisOnly) {
      // 契约 §3.2.1 THIS：例外行（已有则更新）+ 主记录 exdates 追加
      if (existing == null) {
        throw StateError('THIS 编辑要求主记录已存在：${e.id}');
      }
      if (occurrenceStart == null) {
        throw StateError('重复日程须指定 occurrenceStart');
      }
      return _upsertThisOnly(e, existing, occurrenceStart);
    }
    if (scope == kernel.EditScope.thisAndFuture) {
      // 契约 §3.2.1 FUTURE：主记录 UNTIL(occurrenceStart-1s) + 新主记录
      if (existing == null) {
        throw StateError('FUTURE 编辑要求主记录已存在：${e.id}');
      }
      if (occurrenceStart == null) {
        throw StateError('重复日程须指定 occurrenceStart');
      }
      return _upsertThisAndFuture(e, existing, occurrenceStart);
    }

    // ALL：直改主记录；改了 startAt 则例外行 original_start_at 平移同偏移；sequence+1
    final sequence = existing == null ? e.sequence : existing.sequence + 1;
    await _db.into(_db.calendarEvents).insertOnConflictUpdate(
          _eventCompanion(e, sequence: sequence),
        );
    if (existing != null && !existing.startAt.isAtSameMomentAs(e.startAt)) {
      final offset = e.startAt.difference(existing.startAt);
      final exceptions = await (_db.select(_db.calendarEvents)
            ..where((t) => t.parentEventId.equals(e.id)))
          .get();
      for (final row in exceptions) {
        await (_db.update(_db.calendarEvents)
              ..where((t) => t.id.equals(row.id)))
            .write(db.CalendarEventsCompanion(
          originalStartAt: Value(row.originalStartAt?.add(offset)),
          startAt: Value(row.startAt.add(offset)),
          endAt: Value(row.endAt.add(offset)),
        ));
      }
    }
    return e.id;
  }

  Future<String> _upsertThisOnly(
    kernel.CalendarEvent e,
    db.CalendarEvent master,
    DateTime occurrenceStart,
  ) async {
    final occ = occurrenceStart.toUtc();
    // 例外行：复制主字段再覆盖请求字段；仅改标题（start 未动）时时间=原始 occurrence
    final startAt =
        e.startAt.isAtSameMomentAs(master.startAt) ? occ : e.startAt;
    final endAt = e.endAt.isAtSameMomentAs(master.endAt)
        ? startAt.add(master.endAt.difference(master.startAt))
        : e.endAt;
    final exId = '${master.id}-ex-${occ.microsecondsSinceEpoch}';
    await _db.into(_db.calendarEvents).insertOnConflictUpdate(
          db.CalendarEventsCompanion.insert(
            id: exId,
            remoteId: Value(e.remoteId),
            calendarId: e.calendarId,
            uid: master.uid,
            title: e.title,
            location: Value(e.location),
            url: Value(e.url),
            notes: Value(e.notes),
            startAt: startAt,
            endAt: endAt,
            allDay: Value(e.allDay),
            timeZone: e.timeZone,
            isFloating: Value(e.isFloating),
            // 例外行不带 rrule（契约 §3.2.1）
            parentEventId: Value(master.id),
            originalStartAt: Value(occ),
            status: Value(e.status.id),
            availability: Value(e.availability.id),
            travelMinutes: Value(e.travelMinutes),
            isPrivate: Value(e.isPrivate),
            alertsJson: Value(_encodeAlerts(e.alerts)),
            inviteesJson: Value(_encodeInvitees(e.invitees)),
            sequence: Value(master.sequence),
            revision: Value(master.revision),
            deletedAt: const Value(null),
            updatedAt: _now,
          ),
        );

    // 主记录 exdates 追加该次（已含则幂等）
    final exdates = {..._decodeExdates(master.exdatesJson), occ}
        .toList(growable: false)
      ..sort();
    await (_db.update(_db.calendarEvents)
          ..where((t) => t.id.equals(master.id)))
        .write(db.CalendarEventsCompanion(
      exdatesJson: Value(_encodeExdates(exdates)),
      updatedAt: Value(_now),
    ));
    return exId;
  }

  Future<String> _upsertThisAndFuture(
    kernel.CalendarEvent e,
    db.CalendarEvent master,
    DateTime occurrenceStart,
  ) async {
    final occ = occurrenceStart.toUtc();
    final until = occ.subtract(const Duration(seconds: 1));
    // 主记录 rrule 追加/替换 UNTIL=(occurrenceStart - 1s)
    final cappedRule = _withUntil(master.rrule, until);
    await (_db.update(_db.calendarEvents)
          ..where((t) => t.id.equals(master.id)))
        .write(db.CalendarEventsCompanion(
      rrule: Value(cappedRule),
      updatedAt: Value(_now),
    ));
    // 删除 ≥ occurrenceStart 的旧例外行
    final stale = await (_db.select(_db.calendarEvents)
          ..where((t) =>
              t.parentEventId.equals(master.id) &
              t.originalStartAt.isBiggerOrEqualValue(occ)))
        .get();
    for (final row in stale) {
      await (_db.delete(_db.calendarEvents)..where((t) => t.id.equals(row.id)))
          .go();
    }
    // 新主记录：字段=请求，rrule=原规则去掉 UNTIL/COUNT
    final startAt =
        e.startAt.isAtSameMomentAs(master.startAt) ? occ : e.startAt;
    final endAt = e.endAt.isAtSameMomentAs(master.endAt)
        ? startAt.add(master.endAt.difference(master.startAt))
        : e.endAt;
    final newId = '${master.id}-f${occ.microsecondsSinceEpoch}';
    final series = kernel.CalendarEvent(
      id: newId,
      remoteId: e.remoteId,
      calendarId: e.calendarId,
      uid: master.uid,
      title: e.title,
      location: e.location,
      url: e.url,
      notes: e.notes,
      startAt: startAt,
      endAt: endAt,
      allDay: e.allDay,
      timeZone: e.timeZone,
      isFloating: e.isFloating,
      rrule: _withoutUntilCount(e.rrule ?? master.rrule),
      exdates: const [],
      status: e.status,
      availability: e.availability,
      travelMinutes: e.travelMinutes,
      isPrivate: e.isPrivate,
      alerts: e.alerts,
      invitees: e.invitees,
      sequence: master.sequence,
      revision: master.revision,
      deletedAt: null,
      updatedAt: _now,
    );
    await _db
        .into(_db.calendarEvents)
        .insert(_eventCompanion(series, sequence: master.sequence));
    return newId;
  }

  @override
  Future<void> deleteEvent(
    String id, {
    kernel.EditScope scope = kernel.EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    await _db.transaction(() async {
      final master = await (_db.select(_db.calendarEvents)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (master == null) return;
      if (scope == kernel.EditScope.thisOnly) {
        if (occurrenceStart == null) {
          throw StateError('重复日程须指定 occurrenceStart');
        }
        final occ = occurrenceStart.toUtc();
        // DELETE THIS → exdates 追加；该次已有例外行则一并移除
        final exceptions = await (_db.select(_db.calendarEvents)
              ..where((t) => t.parentEventId.equals(id)))
            .get();
        for (final row in exceptions) {
          if (row.originalStartAt != null &&
              row.originalStartAt!.isAtSameMomentAs(occ)) {
            await (_db.delete(_db.calendarEvents)
                  ..where((t) => t.id.equals(row.id)))
                .go();
          }
        }
        final exdates = {..._decodeExdates(master.exdatesJson), occ}
            .toList(growable: false)
          ..sort();
        await (_db.update(_db.calendarEvents)
              ..where((t) => t.id.equals(id)))
            .write(db.CalendarEventsCompanion(
          exdatesJson: Value(_encodeExdates(exdates)),
          updatedAt: Value(_now),
        ));
        return;
      }
      if (scope == kernel.EditScope.thisAndFuture) {
        if (occurrenceStart == null) {
          throw StateError('重复日程须指定 occurrenceStart');
        }
        await (_db.update(_db.calendarEvents)
              ..where((t) => t.id.equals(id)))
            .write(db.CalendarEventsCompanion(
          rrule: Value(_withUntil(
              master.rrule,
              occurrenceStart
                  .toUtc()
                  .subtract(const Duration(seconds: 1)))),
          updatedAt: Value(_now),
        ));
        await (_db.delete(_db.calendarEvents)
              ..where((t) =>
                  t.parentEventId.equals(id) &
                  t.originalStartAt.isBiggerOrEqualValue(
                      occurrenceStart.toUtc())))
            .go();
        return;
      }
      // ALL → 软删主 + 例外
      await (_db.update(_db.calendarEvents)
            ..where((t) => t.id.equals(id) | t.parentEventId.equals(id)))
          .write(db.CalendarEventsCompanion(deletedAt: Value(_now)));
    });
  }

  @override
  Future<void> moveEvent(String id, String targetCalendarId) async {
    await _db.transaction(() async {
      await _assertWritable(targetCalendarId);
      await (_db.update(_db.calendarEvents)
            ..where((t) => t.id.equals(id) | t.parentEventId.equals(id)))
          .write(db.CalendarEventsCompanion(
        calendarId: Value(targetCalendarId),
        updatedAt: Value(_now),
      ));
    });
  }

  @override
  Future<List<kernel.CalendarEvent>> search(
    String keyword, {
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) async {
    final pattern = '%$keyword%';
    final query = _db.select(_db.calendarEvents)
      ..where((t) => t.deletedAt.isNull())
      ..where((t) =>
          t.title.like(pattern) |
          t.location.like(pattern) |
          t.notes.like(pattern));
    if (from != null) {
      query.where((t) => t.endAt.isBiggerThanValue(from));
    }
    if (to != null) {
      query.where((t) => t.startAt.isSmallerThanValue(to));
    }
    query.limit(limit);
    final rows = await query.get();
    return rows.map(_eventModel).toList(growable: false);
  }

  @override
  Stream<kernel.CalendarPreference> watchPreference() {
    final query = _db.select(_db.calendarPreferences)
      ..where((t) => t.userKey.equals(_localUserKey));
    return query.watchSingleOrNull().map(
          (row) => row == null
              ? kernel.CalendarPreference.defaults
              : _preferenceModel(row),
        );
  }

  @override
  Future<void> savePreference(kernel.CalendarPreference p) async {
    final existing = await (_db.select(_db.calendarPreferences)
          ..where((t) => t.userKey.equals(_localUserKey)))
        .getSingleOrNull();
    final revision = (existing?.revision ?? 0) + 1;
    await _db.into(_db.calendarPreferences).insertOnConflictUpdate(
          db.CalendarPreferencesCompanion.insert(
            userKey: _localUserKey,
            defaultCalendarId: Value(p.defaultCalendarId),
            startWeekOn: Value(p.startWeekOn),
            weekViewDays: Value(p.weekViewDays),
            dayStartHour: Value(p.dayStartHour),
            dayEndHour: Value(p.dayEndHour),
            hoursShown: Value(p.hoursShown),
            showDeclinedEvents: Value(p.showDeclinedEvents),
            timeZoneSupport: Value(p.timeZoneSupport),
            displayTimeZone: Value(p.displayTimeZone),
            defaultAlertTimedMinutes: Value(p.defaultAlertTimedMinutes),
            defaultAlertAllDayDays: Value(p.defaultAlertAllDayDays),
            defaultAlertAllDayTime: Value(p.defaultAlertAllDayTime),
            defaultDurationMinutes: Value(p.defaultDurationMinutes),
            alternateCalendar: Value(p.alternateCalendar.id),
            showWeekNumbers: Value(p.showWeekNumbers),
            weekViewStartsToday: Value(p.weekViewStartsToday),
            showHolidays: Value(p.showHolidays),
            openEventsInWindow: Value(p.openEventsInWindow),
            revision: Value(revision),
          ),
        );
  }

  // ---- 内部 ----

  /// 只读日历守卫（TC-CAL-KR-510；契约 1_070_105）。
  Future<void> _assertWritable(String calendarId) async {
    final cal = await (_db.select(_db.calendars)
          ..where((t) => t.id.equals(calendarId)))
        .getSingleOrNull();
    if (cal == null) {
      throw StateError('日历不存在：$calendarId');
    }
    final kind = kernel.CalendarKind.fromId(cal.kind);
    final permission = kernel.CalendarPermission.fromId(cal.permission);
    final writable = kind == kernel.CalendarKind.local ||
        (kind == kernel.CalendarKind.shared &&
            permission != kernel.CalendarPermission.view);
    if (!writable) {
      throw StateError('该日历为只读（订阅/节假日/仅查看共享）：$calendarId');
    }
  }

  /// FUTURE：主记录 rrule 追加/替换 UNTIL。
  String _withUntil(String? rrule, DateTime until) {
    final parts = (rrule ?? '')
        .split(';')
        .where((p) => p.isNotEmpty && !p.startsWith('UNTIL='))
        .toList()
      ..add('UNTIL=${_rfcUntil(until)}');
    return parts.join(';');
  }

  /// FUTURE 新系列：去掉 UNTIL/COUNT。
  String _withoutUntilCount(String? rrule) {
    return (rrule ?? '')
        .split(';')
        .where((p) =>
            p.isNotEmpty && !p.startsWith('UNTIL=') && !p.startsWith('COUNT='))
        .join(';');
  }

  /// RFC 5545 UNTIL UTC 格式：YYYYMMDDTHHMMSSZ。
  String _rfcUntil(DateTime utc) {
    final u = utc.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T'
        '${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  kernel.Calendar _calendarModel(db.Calendar row) {
    return kernel.Calendar(
      id: row.id,
      remoteId: row.remoteId,
      title: row.title,
      colorArgb: row.colorArgb,
      kind: kernel.CalendarKind.fromId(row.kind) ?? kernel.CalendarKind.local,
      groupName: row.groupName,
      isVisible: row.isVisible,
      isDefault: row.isDefault,
      sortOrder: row.sortOrder,
      ignoreAlerts: row.ignoreAlerts,
      sourceUrl: row.sourceUrl,
      refreshMinutes: row.refreshMinutes,
      holidayRegion: row.holidayRegion,
      lastRefreshError: row.lastRefreshError,
      permission: kernel.CalendarPermission.fromId(row.permission) ??
          kernel.CalendarPermission.owner,
      revision: row.revision,
      deletedAt: row.deletedAt?.toUtc(),
    );
  }

  kernel.CalendarEvent _eventModel(db.CalendarEvent row) {
    return kernel.CalendarEvent(
      id: row.id,
      remoteId: row.remoteId,
      calendarId: row.calendarId,
      uid: row.uid,
      title: row.title,
      location: row.location,
      url: row.url,
      notes: row.notes,
      startAt: row.startAt.toUtc(),
      endAt: row.endAt.toUtc(),
      allDay: row.allDay,
      timeZone: row.timeZone,
      isFloating: row.isFloating,
      rrule: row.rrule,
      exdates: _decodeExdates(row.exdatesJson),
      parentEventId: row.parentEventId,
      originalStartAt: row.originalStartAt?.toUtc(),
      status:
          kernel.EventStatus.fromId(row.status) ?? kernel.EventStatus.confirmed,
      availability: kernel.EventAvailability.fromId(row.availability) ??
          kernel.EventAvailability.busy,
      travelMinutes: row.travelMinutes,
      isPrivate: row.isPrivate,
      alerts: _decodeAlerts(row.alertsJson),
      invitees: _decodeInvitees(row.inviteesJson),
      sequence: row.sequence,
      revision: row.revision,
      deletedAt: row.deletedAt?.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  db.CalendarEventsCompanion _eventCompanion(
    kernel.CalendarEvent e, {
    required int sequence,
  }) {
    return db.CalendarEventsCompanion.insert(
      id: e.id,
      remoteId: Value(e.remoteId),
      calendarId: e.calendarId,
      uid: e.uid,
      title: e.title,
      location: Value(e.location),
      url: Value(e.url),
      notes: Value(e.notes),
      startAt: e.startAt,
      endAt: e.endAt,
      allDay: Value(e.allDay),
      timeZone: e.timeZone,
      isFloating: Value(e.isFloating),
      rrule: Value(e.rrule),
      exdatesJson: Value(_encodeExdates(e.exdates)),
      parentEventId: Value(e.parentEventId),
      originalStartAt: Value(e.originalStartAt),
      status: Value(e.status.id),
      availability: Value(e.availability.id),
      travelMinutes: Value(e.travelMinutes),
      isPrivate: Value(e.isPrivate),
      alertsJson: Value(_encodeAlerts(e.alerts)),
      inviteesJson: Value(_encodeInvitees(e.invitees)),
      sequence: Value(sequence),
      revision: Value(e.revision),
      deletedAt: Value(e.deletedAt),
      updatedAt: e.updatedAt,
    );
  }

  kernel.CalendarPreference _preferenceModel(db.CalendarPreference row) {
    return kernel.CalendarPreference(
      defaultCalendarId: row.defaultCalendarId,
      startWeekOn: row.startWeekOn,
      weekViewDays: row.weekViewDays,
      dayStartHour: row.dayStartHour,
      dayEndHour: row.dayEndHour,
      hoursShown: row.hoursShown,
      showDeclinedEvents: row.showDeclinedEvents,
      timeZoneSupport: row.timeZoneSupport,
      displayTimeZone: row.displayTimeZone,
      defaultAlertTimedMinutes: row.defaultAlertTimedMinutes,
      defaultAlertAllDayDays: row.defaultAlertAllDayDays,
      defaultAlertAllDayTime: row.defaultAlertAllDayTime,
      defaultDurationMinutes: row.defaultDurationMinutes,
      alternateCalendar:
          kernel.AlternateCalendar.fromId(row.alternateCalendar) ??
              kernel.AlternateCalendar.none,
      showWeekNumbers: row.showWeekNumbers,
      weekViewStartsToday: row.weekViewStartsToday,
      showHolidays: row.showHolidays,
      openEventsInWindow: row.openEventsInWindow,
      revision: row.revision,
    );
  }

  static String _encodeExdates(List<DateTime> exdates) => jsonEncode(
        [for (final d in exdates) d.toUtc().toIso8601String()],
      );

  static List<DateTime> _decodeExdates(String raw) {
    final decoded = _decodeJsonList(raw);
    return [
      for (final item in decoded)
        if (item is String) DateTime.parse(item).toUtc(),
    ];
  }

  static String _encodeAlerts(List<kernel.EventAlert> alerts) => jsonEncode([
        for (final a in alerts)
          {
            if (a.offsetMinutes != null) 'offsetMinutes': a.offsetMinutes,
            if (a.allDayOffsetDays != null)
              'allDayOffsetDays': a.allDayOffsetDays,
            if (a.allDayTime != null) 'allDayTime': a.allDayTime,
          },
      ]);

  static List<kernel.EventAlert> _decodeAlerts(String raw) {
    return [
      for (final item in _decodeJsonList(raw))
        if (item is Map<String, dynamic>)
          kernel.EventAlert(
            offsetMinutes: item['offsetMinutes'] as int?,
            allDayOffsetDays: item['allDayOffsetDays'] as int?,
            allDayTime: item['allDayTime'] as String?,
          ),
    ];
  }

  static String _encodeInvitees(List<kernel.EventInvitee> invitees) =>
      jsonEncode([
        for (final i in invitees)
          {
            'memberUserId': i.memberUserId,
            if (i.displayName != null) 'displayName': i.displayName,
            'role': i.role.id,
            'partstat': i.partstat.id,
            if (i.comment != null) 'comment': i.comment,
            if (i.proposedStartAt != null)
              'proposedStartAt': i.proposedStartAt!.toUtc().toIso8601String(),
            if (i.proposedEndAt != null)
              'proposedEndAt': i.proposedEndAt!.toUtc().toIso8601String(),
            if (i.invitedAt != null)
              'invitedAt': i.invitedAt!.toUtc().toIso8601String(),
          },
      ]);

  static List<kernel.EventInvitee> _decodeInvitees(String raw) {
    return [
      for (final item in _decodeJsonList(raw))
        if (item is Map<String, dynamic>)
          kernel.EventInvitee(
            memberUserId: item['memberUserId'] as String,
            displayName: item['displayName'] as String?,
            role: kernel.InviteeRole.fromId(item['role'] as String?) ??
                kernel.InviteeRole.required,
            partstat: kernel.PartStat.fromId(item['partstat'] as String?) ??
                kernel.PartStat.needsAction,
            comment: item['comment'] as String?,
            proposedStartAt: _parseIso(item['proposedStartAt'] as String?),
            proposedEndAt: _parseIso(item['proposedEndAt'] as String?),
            invitedAt: _parseIso(item['invitedAt'] as String?),
          ),
    ];
  }

  static DateTime? _parseIso(String? raw) =>
      raw == null ? null : DateTime.parse(raw).toUtc();

  static List<dynamic> _decodeJsonList(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {
      // 容错：损坏数据按空列表处理
    }
    return const [];
  }
}
