import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../models/reminder_item.dart';
import '../models/reminder_list.dart';
import '../models/reminder_list_type.dart';
import '../models/reminder_section.dart';

/// 发件箱条目（本地已发生、尚未被服务端接受的变更）。
///
/// `clientMutationId` 在**入队时**生成并从此固定：同实体的后续编辑只更新载荷，
/// 不换键——服务端按幂等键去重，断网重推与合并批都必须沿用同一个键（TC-SYNC-108）。
@immutable
final class SyncOutboxEntry extends Equatable {
  const SyncOutboxEntry({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.clientMutationId,
    required this.clientUpdatedAt,
  });

  /// `task`（本卡只任务域；`list`/`task_section` 待列表侧有 remoteId 后接）。
  final String entityType;

  /// 本地实体 id（离线新建即本地 UUID，服务端经临时 ID 映射认它）。
  final String entityId;

  /// `upsert` / `delete`。
  final String operation;

  /// 变更时刻的实体快照（键名对齐服务端 `LifeosTaskSyncCodec.taskPayload`）。
  final Map<String, dynamic> payload;

  /// 幂等键（入队生成，重放不换）。
  final String clientMutationId;

  /// 入队时刻（epoch 毫秒）；同实体多次编辑取最新，出队按此升序。
  final int clientUpdatedAt;

  @override
  List<Object?> get props =>
      [entityType, entityId, operation, payload, clientMutationId, clientUpdatedAt];
}

/// 同步发件箱端口：本地写入与「待推队列」同事务落库，重启不丢（flutter#124 卡 2）。
abstract interface class SyncOutbox {
  /// 登记一条变更；同 (entityType, entityId) 已有未推条目时**合并**
  /// （载荷与 operation 取最新，幂等键保留）。
  Future<void> enqueue(SyncOutboxEntry entry);

  /// 待推条目，按 [SyncOutboxEntry.clientUpdatedAt] 升序（同刻按 entityId）。
  Future<List<SyncOutboxEntry>> pending();

  /// 服务端已处置该变更 → 出队。
  ///
  /// [serverId] 非空时同时把本地实体的 `remoteId` 回填（TC-SYNC-112 临时 ID 映射收口）；
  /// 冲突让位（接受服务端值）调用时不传 serverId，只清队不改写。
  Future<void> acknowledge({
    required String entityType,
    required String entityId,
    String? serverId,
  });
}

/// 服务端语义的落库侧（flutter#124 卡 3）：把一批入站变更写进本地存储。
///
/// 与 [SyncOutbox] 的关键区别：**入站落库不得再回写发件箱**，
/// 否则 pull→enqueue→push 会自己造出无限往返。
abstract interface class SyncApplier {
  /// 落一批入站变更（同事务：要么全落、要么都不落，游标由调用方在成功后前进）。
  Future<void> applyAll(Iterable<SyncIncomingChange> changes);
}

/// 任务域增量游标的持久化端口（TC-SYNC-107「游标前进」的本地半边）。
abstract interface class SyncCursorStore {
  /// 上次成功落库的游标；null = 从未同步过（首次全量）。
  Future<String?> read();

  /// 覆盖写入（一个域一行）。
  Future<void> write(String cursor);
}

/// 入站变更（服务端下推的一条变更向量）。
@immutable
final class SyncIncomingChange extends Equatable {
  const SyncIncomingChange({
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.payload = const {},
  });

  final String entityType;

  /// 服务端实体 id（本地行的 `remoteId`）。
  final String entityId;

  /// `upsert` / `delete`。
  final String operation;

  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [entityType, entityId, operation, payload];
}

/// 任务域同步载荷 → 提醒条目（[taskSyncPayload] 的逆向；服务端 0–3 档回转客户端档）。
///
/// 日期是 epoch 毫秒（服务端 `LifeosTaskCodec.epochMilli` 同口径），解回本地 DateTime；
/// 缺键按「不动该字段」的中性值处理，损坏载荷不炸整批。
ReminderItem reminderItemFromSyncPayload(
  Map<String, dynamic> payload, {
  required String entityId,
  required String listId,
  ReminderItem? existing,
}) {
  int? asInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
  DateTime? asDate(Object? v) => v is num
      ? DateTime.fromMillisecondsSinceEpoch(v.toInt())
      : (v == null ? null : DateTime.tryParse('$v'));
  bool asBool(Object? v, bool fallback) => v is bool
      ? v
      : (v == null
          ? fallback
          : ('' == '$v' ? fallback : ('1' == '$v' || 'true' == '$v')));
  String? asString(Object? v) => v?.toString();
  Object? pick(String camel, String snake) =>
      payload.containsKey(camel) ? payload[camel] : payload[snake];

  final tagsRaw = payload['tags'];
  return ReminderItem(
    id: existing?.id ?? entityId,
    listId: listId,
    title: asString(payload['title']) ?? existing?.title ?? '',
    notes: asString(payload['notes']) ??
        asString(payload['description']) ??
        existing?.notes,
    isCompleted: asBool(payload['isCompleted'], existing?.isCompleted ?? false),
    isFlagged: asBool(
        pick('isFlagged', 'is_flagged') ?? payload['isFlagged'],
        existing?.isFlagged ?? false),
    dueAt: asDate(payload['dueAt']) ?? existing?.dueAt,
    priority: payload.containsKey('priority')
        ? ReminderPriorityCodec.fromServer(asInt(payload['priority']) ?? 0)
        : (existing?.priority ?? 0),
    tags: tagsRaw is List
        ? tagsRaw.whereType<String>().toList(growable: false)
        : (existing?.tags ?? const []),
    recurrence: asString(payload['recurrence']) ?? existing?.recurrence,
    recurrenceUntil: asDate(payload['recurrenceUntil']) ??
        existing?.recurrenceUntil,
    parentId: asString(pick('parentTaskId', 'parent_task_id')) ??
        existing?.parentId,
    sortOrder: asInt(payload['sortOrder']) ?? existing?.sortOrder ?? 0,
    remoteId: entityId,
    completedAt: asDate(payload['completedAt']) ?? existing?.completedAt,
    sectionId: asString(pick('sectionId', 'section_id')) ??
        existing?.sectionId,
    deletedAt: asDate(payload['deletedAt']) ?? existing?.deletedAt,
  );
}

/// 提醒条目 → 任务域同步载荷（服务端 push/pull 两侧读的就是这套键名）。
///
/// 日期一律 epoch 毫秒（`LifeosTaskSyncCodec.epochMilli` 同口径）；
/// `isFlagged` 双键（camel + snake）沿用 Todo 线 TC-API-103 的拼写兼容；
/// `priority` 走**服务端 0–3 档**（`LifeosTaskDO` 冻结并有 DB CHECK，
/// 直接发客户端的 0/1/5/9 会被 CHECK 拒掉）。
Map<String, dynamic> taskSyncPayload(ReminderItem item) => {
      'id': item.id,
      'listId': item.listId,
      'sectionId': item.sectionId,
      'parentTaskId': item.parentId,
      'title': item.title,
      'description': item.notes,
      'notes': item.notes,
      'dueAt': _epochMilli(item.dueAt),
      'priority': ReminderPriorityCodec.toServer(item.priority),
      'isFlagged': item.isFlagged,
      'is_flagged': item.isFlagged,
      'isCompleted': item.isCompleted,
      'completedAt': _epochMilli(item.completedAt),
      'sortOrder': item.sortOrder,
      'deletedAt': _epochMilli(item.deletedAt),
      'tags': item.tags,
      'recurrence': item.recurrence,
    };

int? _epochMilli(DateTime? value) => value?.toUtc().millisecondsSinceEpoch;

/// 清单 → 任务域同步载荷（服务端 `LifeosTaskSyncCodec.listPayload` 同键名）。
///
/// flutter#144 / TC-SYNC-106 出站半边。`id` 优先发服务端 ID（remoteId）；
/// 本地新建的清单发本地 id，由服务端物化后回填。`icon` 本地无对应字段故省略
/// （服务端是部分更新语义：省略=保持）。
Map<String, dynamic> listSyncPayload(ReminderList list) => {
      'id': list.remoteId ?? list.id,
      'name': list.title,
      'color': list.colorArgb,
      'type': list.listType.id,
      'isSmart': list.isSmart,
      'smartFilter': list.smartFilter == null
          ? null
          : jsonEncode({
              'tagEquals': list.smartFilter!.tagEquals,
              'flaggedOnly': list.smartFilter!.flaggedOnly,
            }),
      'sortOrder': list.sortOrder,
    };

/// 任务域清单载荷 → [ReminderList]（[listSyncPayload] 的逆向）。
///
/// 缺键按「不动该字段」的中性值处理；`sections` 不在此还原（分区是独立的
/// `task_section` 实体，随各自变更落进 `sections_json`）。
ReminderList reminderListFromSyncPayload(
  Map<String, dynamic> payload, {
  required String entityId,
  ReminderList? existing,
}) {
  int? asInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
  bool asBool(Object? v, bool fallback) => v is bool
      ? v
      : (v == null
          ? fallback
          : ('' == '$v' ? fallback : ('1' == '$v' || 'true' == '$v')));
  String? asString(Object? v) => v?.toString();
  var filter = existing?.smartFilter;
  final rawFilter = asString(payload['smartFilter']);
  if (rawFilter != null && rawFilter.isNotEmpty) {
    try {
      final decoded = jsonDecode(rawFilter);
      if (decoded is Map) {
        filter = SmartListFilter(
          tagEquals: decoded['tagEquals'] as String?,
          flaggedOnly: (decoded['flaggedOnly'] as bool?) ?? false,
        );
      }
    } catch (_) {}
  }
  return ReminderList(
    id: existing?.id ?? entityId,
    title: asString(payload['name']) ?? existing?.title ?? '',
    colorArgb: asInt(payload['color']) ?? existing?.colorArgb ?? 0xFF007AFF,
    isSmart: asBool(payload['isSmart'], existing?.isSmart ?? false),
    itemCount: existing?.itemCount ?? 0,
    sortOrder: asInt(payload['sortOrder']) ?? existing?.sortOrder ?? 0,
    sections: existing?.sections ?? const [],
    groupName: existing?.groupName,
    listType: ReminderListType.fromId(asString(payload['type'])),
    smartFilter: filter,
    remoteId: entityId,
  );
}

/// 分区 → 任务域同步载荷（服务端 `LifeosTaskSyncCodec.sectionPayload` 同键名）。
Map<String, dynamic> sectionSyncPayload({
  required String listId,
  required ReminderSection section,
}) =>
    {
      'id': section.remoteId ?? section.id,
      'listId': listId,
      'name': section.title,
      'sortOrder': section.sortOrder,
    };

/// 任务域分区载荷 → [ReminderSection]（[sectionSyncPayload] 的逆向）。
ReminderSection reminderSectionFromSyncPayload(
  Map<String, dynamic> payload, {
  required String entityId,
  ReminderSection? existing,
}) {
  int? asInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
  return ReminderSection(
    id: existing?.id ?? entityId,
    title: payload['name']?.toString() ?? existing?.title ?? '',
    sortOrder: asInt(payload['sortOrder']) ?? existing?.sortOrder ?? 0,
    remoteId: entityId,
  );
}
