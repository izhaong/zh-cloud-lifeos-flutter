/// 日历同步 DTO（契约 §3.9；F-17）。
library;

class CalendarPullChange {
  const CalendarPullChange({
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.revision,
    this.payload = const {},
  });

  final String entityType;
  final String entityId;
  final String operation;
  final int? revision;
  final Map<String, dynamic> payload;
}

class CalendarPullResult {
  const CalendarPullResult({
    required this.changes,
    required this.tombstones,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<CalendarPullChange> changes;
  final List<CalendarPullChange> tombstones;
  final String? nextCursor;
  final bool hasMore;
}

class CalendarPushChange {
  const CalendarPushChange({
    required this.entityType,
    required this.entityId,
    required this.payload,
    this.operation = 'UPSERT',
    this.baseRevision,
    this.clientMutationId,
    this.clientUpdatedAt,
  });

  final String entityType;
  final String entityId;
  final String operation;
  final int? baseRevision;
  final Map<String, dynamic> payload;
  final String? clientMutationId;
  final String? clientUpdatedAt;

  Map<String, dynamic> toJson() => {
        'entityType': entityType,
        'entityId': entityId,
        'operation': operation,
        if (baseRevision != null) 'baseRevision': baseRevision,
        'payload': payload,
        if (clientMutationId != null) 'clientMutationId': clientMutationId,
        if (clientUpdatedAt != null) 'clientUpdatedAt': clientUpdatedAt,
      };
}

class CalendarAccepted {
  const CalendarAccepted({
    this.clientMutationId,
    required this.entityId,
    this.revision,
  });

  final String? clientMutationId;
  final String entityId;
  final int? revision;
}

class CalendarConflict {
  const CalendarConflict({
    this.clientMutationId,
    this.reason,
    this.serverValue = const {},
    this.clientValue = const {},
  });

  final String? clientMutationId;
  final String? reason;
  final Map<String, dynamic> serverValue;
  final Map<String, dynamic> clientValue;
}

class CalendarPushResult {
  const CalendarPushResult({
    this.ok = true,
    this.idempotent = false,
    this.accepted = const [],
    this.conflicts = const [],
    this.nextCursor,
  });

  final bool ok;
  final bool idempotent;
  final List<CalendarAccepted> accepted;
  final List<CalendarConflict> conflicts;
  final String? nextCursor;
}

class CalendarSyncException implements Exception {
  CalendarSyncException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'CalendarSyncException($statusCode): $message';
}


/// 同步端口接口（协调器依赖；REST 实现见 RestCalendarSyncPort）。
abstract interface class CalendarSyncPort {
  Future<CalendarPullResult?> pull({
    required String deviceId,
    String? cursor,
    int limit,
  });

  Future<CalendarPushResult?> push({
    required String deviceId,
    required String idempotencyKey,
    required List<CalendarPushChange> changes,
  });
}
