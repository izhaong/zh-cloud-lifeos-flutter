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

/// push 结果（#428：带**逐条回执**，不再只有 attempts/conflicts）。
class NotePushResult {
  const NotePushResult({
    required this.attempts,
    required this.conflicts,
    this.allAccepted = false,
    this.acceptedEntityIds = const {},
  });

  final int attempts;
  final int conflicts;

  /// 服务端 `ok=true`：整批受理（`accepted` 可能为空数组，但语义是「全收」）。
  final bool allAccepted;

  /// 服务端逐条受理的 entityId（`ok=false` 时只有这些能安全出队）。
  final Set<String> acceptedEntityIds;

  /// 某条变更是否**可以出队**。
  ///
  /// 判据取保守一侧：只有明确受理才出队——服务端没给逐条回执时（老版本/异常响应），
  /// `allAccepted` 为 false 且集合为空，于是**全批保留**（宁可重复推，不可丢变更）。
  bool isAcknowledged(String entityId) =>
      allAccepted || acceptedEntityIds.contains(entityId);
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
