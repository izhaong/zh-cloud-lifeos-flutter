import 'package:feature_productivity_kernel/feature_productivity_kernel.dart' as kernel;

/// 同步会话（未登录 = null，零请求）。
class NoteSyncSession {
  const NoteSyncSession({required this.token, required this.userId});

  final String token;
  final String userId;
}

/// 同步实体类型（契约 §6）。
enum NoteSyncEntityType { folder, note, tag }

/// 待推送变更。
class NoteSyncChange {
  const NoteSyncChange({
    required this.entityType,
    required this.payload,
    this.operation = 'UPSERT',
  });

  final NoteSyncEntityType entityType;
  final Map<String, dynamic> payload;
  final String operation;
}

/// push 结果。
class NotePushResult {
  const NotePushResult({required this.attempts, required this.conflicts});

  final int attempts;
  final int conflicts;
}

/// 一次 pull 的分页结果（#415）：变更向量 + 下一页游标 + 是否还有更多。
class NotePullPage {
  const NotePullPage({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<kernel.SyncIncomingChange> changes;
  final String? nextCursor;
  final bool hasMore;
}
