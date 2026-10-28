import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart'
    show OrderingTerm, Value, BooleanExpressionOperators;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;

import 'db.dart';
import 'drift_sync_outbox.dart';

/// [kernel.ReminderRepository] 的 Drift 实现（离线持久化）。
///
/// - `watch*` 基于 drift 响应式 watch 流，写操作自动推送新快照
/// - 编辑语义（Phase 2 拍板）：全字段编辑 = copyWith + upsertItem 全量回写；
///   toggle 留仓库层（防读改写丢更新 + 重复滚动）；删除为级联语义动作
/// - 智能列表语义过滤与 InMemory 实现一致；排序契约 `sortOrder asc, id asc`
/// - UI 不接触 drift 类型：本包只向端口吐 kernel 实体
class DriftReminderRepository
    implements kernel.ReminderRepository, kernel.SyncApplier {
  DriftReminderRepository(this._db);

  final LifeProductivityDb _db;

  /// 测试注入「当前时间」（与 InMemory.nowForTest 对齐）。
  DateTime? nowForTest;

  DateTime get _now => nowForTest ?? DateTime.now();

  /// 智能列表元数据（不落表，watchLists 派生时合并）。
  static const List<kernel.ReminderList> smartLists = [
    kernel.ReminderList(id: 'smart.today', title: '今天', isSmart: true),
    kernel.ReminderList(id: 'smart.scheduled', title: '计划', isSmart: true),
    kernel.ReminderList(id: 'smart.all', title: '全部', isSmart: true),
    kernel.ReminderList(id: 'smart.flagged', title: '旗标', isSmart: true),
    kernel.ReminderList(id: 'smart.urgent', title: '紧急', isSmart: true),
    kernel.ReminderList(id: 'smart.completed', title: '完成', isSmart: true),
    kernel.ReminderList(id: 'smart.assigned', title: '分配事项', isSmart: true),
    kernel.ReminderList(id: 'smart.trash', title: '最近删除', isSmart: true),
  ];

  @override
  Stream<List<kernel.ReminderList>> watchLists() {
    final lists$ = _db.select(_db.reminderLists).watch();
    final items$ = _db.select(_db.reminderItems).watch();
    // 跨日刷新：now 不能在建流时冻结——与日界 tick 合并，每次发射重算
    return _combineLatest3<
      List<ReminderList>,
      List<ReminderItem>,
      DateTime,
      List<kernel.ReminderList>
    >(lists$, items$, _dayTicks(), (listRows, itemRows, _) {
      final now = _now;
      return [
        for (final smart in smartLists)
          smart.copyWith(itemCount: _count(itemRows, smart.id, now)),
        for (final row in listRows)
          kernel.ReminderList(
            id: row.id,
            title: row.title,
            colorArgb: row.colorArgb,
            isSmart: row.isSmart,
            itemCount: _count(itemRows, row.id, now),
            sortOrder: row.sortOrder,
            sections: _sortedSections(_decodeSections(row.sectionsJson)),
            groupName: row.groupName,
            listType: kernel.ReminderListType.fromId(row.listType),
            smartFilter: _decodeSmartFilter(row.smartFilter),
            remoteId: row.remoteId,
          ),
      ];
    });
  }

  @override
  Stream<List<kernel.ReminderItem>> watchItems({
    String? listId,
    bool includeCompleted = false,
  }) {
    final query = _db.select(_db.reminderItems)
      // 排序契约（与 InMemory 一致）：sortOrder asc, id asc
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.id),
      ]);
    if (listId != null && !listId.startsWith('smart.')) {
      query.where((t) => t.listId.equals(listId));
      // 回收窗行不进普通列表（软删只在 smart.trash 出现）
      query.where((t) => t.deletedAt.isNull());
    }
    return _combineLatest2<
      List<ReminderItem>,
      DateTime,
      List<kernel.ReminderItem>
    >(query.watch(), _dayTicks(), (rows, _) {
      final now = _now;
      return List<kernel.ReminderItem>.unmodifiable(
        rows
            .where(
              (row) => _matches(
                row,
                listId,
                now,
                includeCompleted: includeCompleted,
              ),
            )
            .map(_toModel)
            .toList(growable: false),
      );
    });
  }

  /// 日界 tick：立即发一次，此后每 60s 检查本地日；跨日才再发。
  /// 修复「app 跨午夜保持打开时智能列表仍是昨天快照」。
  Stream<DateTime> _dayTicks() {
    DateTime last = _todayOf(_now);
    late StreamController<DateTime> controller;
    Timer? timer;
    void emitIfDayChanged() {
      final t = _now;
      final today = _todayOf(t);
      if (today.year != last.year ||
          today.month != last.month ||
          today.day != last.day) {
        last = today;
        if (controller.hasListener) controller.add(t);
      }
    }

    controller = StreamController<DateTime>.broadcast(
      onListen: () {
        controller.add(_now);
        timer ??= Timer.periodic(const Duration(seconds: 60), (_) {
          emitIfDayChanged();
        });
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );
    return controller.stream;
  }

  static DateTime _todayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// 跨日刷新（供壳层在回前台时调用）：无集中 timer——
  /// watch 流已内置日界 tick，这里只做一次性对账。
  @override
  bool checkDayRollover() => true;

  @override
  Future<void> upsertItem(kernel.ReminderItem item) async {
    if (item.id.startsWith('smart.')) {
      throw ArgumentError('smart. 前缀保留给智能列表派生，禁止作为条目 id');
    }
    await _db.transaction(() async {
      // 防复活（cursor PR#12）：软删行只经 restoreItem 恢复；
      // 对已删条目的全量回写（deletedAt 丢失）保留回收窗标记
      final existing = await (_db.select(
        _db.reminderItems,
      )..where((t) => t.id.equals(item.id))).getSingleOrNull();
      await _db
          .into(_db.reminderItems)
          .insertOnConflictUpdate(_companionFrom(item));
      if (existing != null &&
          existing.deletedAt != null &&
          item.deletedAt == null) {
        await (_db.update(
          _db.reminderItems,
        )..where((t) => t.id.equals(item.id))).write(
          ReminderItemsCompanion(deletedAt: Value(existing.deletedAt)),
        );
      }
      await _enqueueOutbox([item.id]);
    });
  }

  @override
  Future<void> toggleCompleted(String itemId) async {
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.reminderItems,
      )..where((t) => t.id.equals(itemId))).getSingleOrNull();
      if (row == null) return;
      final cur = _toModel(row);
      final rule = cur.recurrenceRule;
      if (rule != null && !cur.isCompleted && cur.dueAt != null) {
        final next = rule.nextOccurrence(cur.dueAt!, _now);
        // T-04（cursor R1）：与 InMemory 同口径——next 越过 recurrenceUntil
        // 当天结束 → 真完成不滚动；否则滚动
        final until = cur.recurrenceUntil;
        final pastEnd =
            until != null &&
            next.isAfter(
              DateTime(until.year, until.month, until.day, 23, 59, 59, 999),
            );
        if (pastEnd) {
          await (_db.update(
            _db.reminderItems,
          )..where((t) => t.id.equals(itemId))).write(
            ReminderItemsCompanion(
              isCompleted: const Value(true),
              completedAt: Value(_now),
            ),
          );
        } else {
          await (_db.update(
            _db.reminderItems,
          )..where((t) => t.id.equals(itemId))).write(
            ReminderItemsCompanion(
              dueAt: Value(next),
              isCompleted: const Value(false),
              completedAt: const Value(null),
            ),
          );
        }
      } else {
        // 完成时间联动（服务端 completedAt 对齐）：完成记当下，取消清空
        await (_db.update(
          _db.reminderItems,
        )..where((t) => t.id.equals(itemId))).write(
          ReminderItemsCompanion(
            isCompleted: Value(!cur.isCompleted),
            completedAt: Value(!cur.isCompleted ? _now : null),
          ),
        );
      }
      await _enqueueOutbox([itemId]);
    });
  }

  @override
  Future<void> toggleFlagged(String itemId) async {
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.reminderItems,
      )..where((t) => t.id.equals(itemId))).getSingleOrNull();
      if (row == null) return;
      await (_db.update(_db.reminderItems)..where((t) => t.id.equals(itemId)))
          .write(ReminderItemsCompanion(isFlagged: Value(!row.isFlagged)));
      await _enqueueOutbox([itemId]);
    });
  }

  @override
  Future<void> moveItem(String itemId, String targetListId) async {
    await _db.transaction(() async {
      final lists = await _db.select(_db.reminderLists).get();
      if (!lists.any((l) => l.id == targetListId && !l.isSmart)) return;
      final rows = await _db.select(_db.reminderItems).get();
      final byId = {for (final r in rows) r.id: r};
      if (!byId.containsKey(itemId)) return;

      // 本条 + 全部后代（子任务随父）
      bool selfOrDescendant(String id) {
        var cursor = byId[id];
        for (var depth = 0; depth < 64 && cursor != null; depth++) {
          if (id == itemId) return true;
          final parent = cursor.parentId == null ? null : byId[cursor.parentId];
          if (parent == null) return false;
          if (parent.id == itemId) return true;
          cursor = parent;
        }
        return false;
      }

      for (final r in rows) {
        if (selfOrDescendant(r.id)) {
          await (_db.update(
            _db.reminderItems,
          )..where((t) => t.id.equals(r.id))).write(
            ReminderItemsCompanion(
              listId: Value(targetListId),
              sectionId: const Value(null), // 分区随列表（TC-API-118）
            ),
          );
          await _enqueueOutbox([r.id]);
        }
      }
    });
  }

  @override
  Future<void> deleteItem(String itemId) async {
    // 软删级联（TC-UI-109）：本条 + 后代进 30 天回收窗（与 InMemory 同语义）
    final cascade = await _cascadeFrom(itemId);
    await _db.transaction(() async {
      await (_db.update(_db.reminderItems)..where((t) => t.id.isIn(cascade)))
          .write(ReminderItemsCompanion(deletedAt: Value(_now)));
      await _enqueueOutbox(cascade);
    });
  }

  @override
  Future<void> restoreItem(String itemId) async {
    await _db.transaction(() async {
      final cascade = await _cascadeFrom(itemId);
      final target = await (_db.select(
        _db.reminderItems,
      )..where((t) => t.id.equals(itemId))).getSingleOrNull();
      if (target == null) return;
      final lists = await _db.select(_db.reminderLists).get();
      final listAlive = lists.any((l) => l.id == target.listId && !l.isSmart);
      String? fallback;
      if (!listAlive) {
        for (final l in lists) {
          if (!l.isSmart) {
            fallback = l.id;
            break;
          }
        }
      }
      if (fallback != null) {
        await (_db.update(
          _db.reminderItems,
        )..where((t) => t.id.isIn(cascade))).write(
          ReminderItemsCompanion(
            listId: Value(fallback),
            deletedAt: const Value(null),
          ),
        );
      } else {
        await (_db.update(_db.reminderItems)..where((t) => t.id.isIn(cascade)))
            .write(const ReminderItemsCompanion(deletedAt: Value(null)));
      }
      await _enqueueOutbox(cascade);
    });
  }

  @override
  Future<int> purgeExpiredDeleted() async {
    final cutoff = _now.subtract(
      kernel.InMemoryReminderRepository.recycleWindow,
    );
    // 查后删：避免 drift 版本比较方法差异，语义与 InMemory 一致
    final rows = await _db.select(_db.reminderItems).get();
    final expired = rows
        .where((r) => r.deletedAt != null && r.deletedAt!.isBefore(cutoff))
        .map((r) => r.id)
        .toSet();
    if (expired.isEmpty) return 0;
    return await (_db.delete(
      _db.reminderItems,
    )..where((t) => t.id.isIn(expired))).go();
  }

  Future<Set<String>> _cascadeFrom(String itemId) async {
    final removed = <String>{itemId};
    var changed = true;
    while (changed) {
      changed = false;
      final rows = await _db.select(_db.reminderItems).get();
      for (final r in rows) {
        if (r.parentId != null &&
            removed.contains(r.parentId) &&
            !removed.contains(r.id)) {
          removed.add(r.id);
          changed = true;
        }
      }
    }
    return removed;
  }

  /// 把受影响条目登记进同步发件箱（flutter#124 卡 2 / TC-SYNC-107）。
  ///
  /// 与业务写表同事务调用：写库成功而队列丢失=变更永不上传，故必须在事务内。
  /// 载荷取**写库后**的行快照；`deletedAt` 非空记 delete（覆盖此前未推的 upsert，
  /// 幂等键由 [DriftSyncOutbox] 保留首条）。
  Future<void> _enqueueOutbox(Iterable<String> itemIds) async {
    final outbox = DriftSyncOutbox(_db);
    for (final id in itemIds) {
      final row = await (_db.select(
        _db.reminderItems,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) continue;
      final at = _now;
      await outbox.enqueue(
        kernel.SyncOutboxEntry(
          entityType: 'task',
          entityId: id,
          operation: row.deletedAt != null ? 'delete' : 'upsert',
          payload: kernel.taskSyncPayload(_toModel(row)),
          clientMutationId: 'task-$id-${at.microsecondsSinceEpoch}',
          clientUpdatedAt: at.millisecondsSinceEpoch,
        ),
      );
    }
  }

  // ---- 入站落库（flutter#124 卡 3 / TC-SYNC-106、109、112）----

  /// 落一批服务端下推的变更。
  ///
  /// 关键约束：**入站落库不进发件箱**——否则 pull 写一次就顺手 enqueue 一条
  /// 出站变更，push 再推回服务端，两端自己造出无限往返。所以这里绕开
  /// [upsertItem]/[deleteItem] 直接写行。
  /// 同事务：一条不落完就不落，调用方（协调器）据此决定游标要不要前进。
  @override
  Future<void> applyAll(Iterable<kernel.SyncIncomingChange> changes) async {
    if (changes.isEmpty) return;
    await _db.transaction(() async {
      for (final c in changes) {
        if (c.entityType == 'task') {
          if (c.operation == 'delete') {
            await _applyInboundDelete(c);
          } else {
            await _applyInboundUpsert(c);
          }
        } else if (c.entityType == 'list') {
          // flutter#144 / TC-SYNC-106：清单入站落库
          if (c.operation == 'delete') {
            await _applyInboundListDelete(c);
          } else {
            await _applyInboundListUpsert(c);
          }
        } else if (c.entityType == 'task_section') {
          if (c.operation == 'delete') {
            await _applyInboundSectionDelete(c);
          } else {
            await _applyInboundSectionUpsert(c);
          }
        }
        // 标签不是服务端实体（LifeosTaskSyncCodec 只有 task/list/task_section）：
        // 本地标签是 reminder_items.tags 的 JSON 数组，随任务载荷走，无行可落。
      }
    });
  }

  Future<void> _applyInboundUpsert(kernel.SyncIncomingChange c) async {
    final existing = await _findByServerId(c.entityId);
    final listId =
        c.payload['listId']?.toString() ??
        (existing?.listId ?? await _firstOwnListId());
    if (listId == null) return; // 无处安放（既没载荷 listId、本地也没自有列表）
    final model = kernel.reminderItemFromSyncPayload(
      c.payload,
      entityId: c.entityId,
      listId: listId,
      existing: existing == null ? null : _toModel(existing),
    );
    await _db
        .into(_db.reminderItems)
        .insertOnConflictUpdate(_companionFrom(model));
  }

  Future<void> _applyInboundDelete(kernel.SyncIncomingChange c) async {
    final target = await _findByServerId(c.entityId);
    if (target == null) return; // 本地没有这条：幂等跳过
    final at = c.payload['deletedAt'] is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (c.payload['deletedAt'] as num).toInt(),
          )
        : _now;
    // 与服务端 applier 同口径：软删入 30 天回收窗，且删父级联整树入窗
    final cascade = await _cascadeFrom(target.id);
    await (_db.update(_db.reminderItems)..where((t) => t.id.isIn(cascade)))
        .write(ReminderItemsCompanion(deletedAt: Value(at)));
  }

  /// 临时 ID 映射的另一半：对端把同一条任务改了几次，落到本地只能更新原行。
  /// 先按 remoteId（服务端 id）找——离线建的行本地 id 是 UUID，回填后 remoteId
  /// 才是服务端 id；找不到再按 id 相等兜底（历史数据把服务端 id 直接当本地 id 用）。
  Future<ReminderItem?> _findByServerId(String entityId) async {
    final byRemote = await (_db.select(
      _db.reminderItems,
    )..where((t) => t.remoteId.equals(entityId))).get();
    if (byRemote.isNotEmpty) return byRemote.first;
    return (_db.select(
      _db.reminderItems,
    )..where((t) => t.id.equals(entityId))).getSingleOrNull();
  }

  /// 清单行 → kernel 模型（`itemCount` 由 watcher 派生，这里不需要）。
  kernel.ReminderList _listModelFrom(ReminderList row) => kernel.ReminderList(
    id: row.id,
    title: row.title,
    colorArgb: row.colorArgb,
    isSmart: row.isSmart,
    sortOrder: row.sortOrder,
    sections: _sortedSections(_decodeSections(row.sectionsJson)),
    groupName: row.groupName,
    listType: kernel.ReminderListType.fromId(row.listType),
    smartFilter: _decodeSmartFilter(row.smartFilter),
    remoteId: row.remoteId,
  );

  /// 清单版临时 ID 映射：先按 remoteId 找，找不到再按 id 兜底（历史数据把
  /// 服务端 id 直接当本地 id 用），与 [_findByServerId] 同口径。
  Future<ReminderList?> _findListByServerId(String entityId) async {
    final byRemote = await (_db.select(
      _db.reminderLists,
    )..where((t) => t.remoteId.equals(entityId))).get();
    if (byRemote.isNotEmpty) return byRemote.first;
    return (_db.select(
      _db.reminderLists,
    )..where((t) => t.id.equals(entityId))).getSingleOrNull();
  }

  Future<void> _applyInboundListUpsert(kernel.SyncIncomingChange c) async {
    final row = await _findListByServerId(c.entityId);
    if (row != null && row.isSmart && !row.id.startsWith('smart.custom.')) {
      return; // 内置智能列表由仓库派生，不接受服务端写入
    }
    final model = kernel.reminderListFromSyncPayload(
      c.payload,
      entityId: c.entityId,
      existing: row == null ? null : _listModelFrom(row),
    );
    await _db
        .into(_db.reminderLists)
        .insertOnConflictUpdate(
          ReminderListsCompanion.insert(
            id: model.id,
            title: model.title,
            colorArgb: Value(model.colorArgb),
            sortOrder: Value(model.sortOrder),
            groupName: Value(model.groupName),
            listType: Value(model.listType.id),
            smartFilter: Value(_encodeSmartFilter(model.smartFilter)),
            sectionsJson: Value(
              _encodeSections(_sortedSections(model.sections)),
            ),
            isSmart: Value(model.isSmart),
            remoteId: Value(model.remoteId),
          ),
        );
  }

  Future<void> _applyInboundListDelete(kernel.SyncIncomingChange c) async {
    final row = await _findListByServerId(c.entityId);
    if (row == null) return; // 幂等：本地没有这条
    // 与本地 deleteList 同口径：条目随清单进回收窗（软删），再删清单行。
    // 服务端级联下推的条目 delete 再落一次也只是重写 deletedAt，幂等。
    await (_db.update(_db.reminderItems)..where((t) => t.listId.equals(row.id)))
        .write(ReminderItemsCompanion(deletedAt: Value(_now)));
    await (_db.delete(
      _db.reminderLists,
    )..where((t) => t.id.equals(row.id))).go();
  }

  Future<void> _applyInboundSectionUpsert(kernel.SyncIncomingChange c) async {
    final listId = c.payload['listId']?.toString();
    if (listId == null) return;
    final row = await _findListByServerId(listId);
    if (row == null) return; // 归属清单还没到：跳过（服务端按批重推）
    final sections = [..._decodeSections(row.sectionsJson)];
    final i = sections.indexWhere(
      (e) => e.remoteId == c.entityId || e.id == c.entityId,
    );
    final section = kernel.reminderSectionFromSyncPayload(
      c.payload,
      entityId: c.entityId,
      existing: i >= 0 ? sections[i] : null,
    );
    if (i >= 0) {
      sections[i] = section;
    } else {
      sections.add(section);
    }
    await _writeSections(row.id, sections);
  }

  Future<void> _applyInboundSectionDelete(kernel.SyncIncomingChange c) async {
    final listId = c.payload['listId']?.toString();
    if (listId == null) return;
    final row = await _findListByServerId(listId);
    if (row == null) return;
    final all = _decodeSections(row.sectionsJson);
    final doomedIds = all
        .where((e) => e.remoteId == c.entityId || e.id == c.entityId)
        .map((e) => e.id)
        .toSet();
    if (doomedIds.isEmpty) return; // 幂等
    final kept = all
        .where((e) => !doomedIds.contains(e.id))
        .toList(growable: false);
    // 级联：挂靠条目兜底「未分区」（与本地 deleteSection 同语义）
    final rows = await (_db.select(
      _db.reminderItems,
    )..where((t) => t.listId.equals(row.id) & t.sectionId.isNotNull())).get();
    for (final r in rows.where((e) => doomedIds.contains(e.sectionId))) {
      await (_db.update(_db.reminderItems)..where((t) => t.id.equals(r.id)))
          .write(const ReminderItemsCompanion(sectionId: Value(null)));
    }
    await _writeSections(row.id, kept);
  }

  /// 清单变更登记进发件箱（flutter#144 / TC-SYNC-106 出站半边）。
  ///
  /// 与业务写表同事务调用；载荷取**写库后**的行快照。[deleted] 为真时记
  /// delete（行已删，载荷用删前快照）。
  Future<void> _enqueueListOutbox(
    kernel.ReminderList list, {
    bool deleted = false,
  }) async {
    final at = _now;
    final entityId = list.remoteId ?? list.id;
    await DriftSyncOutbox(_db).enqueue(
      kernel.SyncOutboxEntry(
        entityType: 'list',
        entityId: entityId,
        operation: deleted ? 'delete' : 'upsert',
        payload: kernel.listSyncPayload(list),
        clientMutationId: 'list-$entityId-${at.microsecondsSinceEpoch}',
        clientUpdatedAt: at.millisecondsSinceEpoch,
      ),
    );
  }

  /// 分区变更登记进发件箱；[listId] 传服务端清单 ID（有 remoteId 用它）。
  Future<void> _enqueueSectionOutbox({
    required String listId,
    required kernel.ReminderSection section,
    bool deleted = false,
  }) async {
    final at = _now;
    final entityId = section.remoteId ?? section.id;
    await DriftSyncOutbox(_db).enqueue(
      kernel.SyncOutboxEntry(
        entityType: 'task_section',
        entityId: entityId,
        operation: deleted ? 'delete' : 'upsert',
        payload: kernel.sectionSyncPayload(listId: listId, section: section),
        clientMutationId: 'task_section-$entityId-${at.microsecondsSinceEpoch}',
        clientUpdatedAt: at.millisecondsSinceEpoch,
      ),
    );
  }

  Future<String?> _firstOwnListId() async {
    final lists = await _db.select(_db.reminderLists).get();
    for (final l in lists) {
      if (!l.isSmart) return l.id;
    }
    return null;
  }

  @override
  Future<void> upsertList(kernel.ReminderList list) async {
    if (list.id.startsWith('smart.')) {
      // TC-UI-116：smart.custom.* 为用户自建智能列表（合法）；
      // 仅内置五预设 + trash 由仓库派生，不得被用户数据占用/篡改。
      if (!list.id.startsWith('smart.custom.')) {
        throw ArgumentError('smart. 前缀保留给智能列表，禁止用户数据占用');
      }
    }
    await _db.transaction(() async {
      await _db
          .into(_db.reminderLists)
          .insertOnConflictUpdate(
            ReminderListsCompanion.insert(
              id: list.id,
              title: list.title,
              colorArgb: Value(list.colorArgb),
              sortOrder: Value(list.sortOrder),
              groupName: Value(list.groupName),
              listType: Value(list.listType.id),
              smartFilter: Value(_encodeSmartFilter(list.smartFilter)),
              // cursor PR#15 阻断2：分区与智能标记必须随列表落库——
              // 否则 grocery 预置分区/custom 智能列表入库即丢。
              sectionsJson: Value(
                _encodeSections(_sortedSections(list.sections)),
              ),
              isSmart: Value(list.isSmart),
              remoteId: Value(list.remoteId),
            ),
          );
      // flutter#144 / TC-SYNC-106 出站半边：清单变更也要进发件箱
      final row = await (_db.select(
        _db.reminderLists,
      )..where((t) => t.id.equals(list.id))).getSingleOrNull();
      if (row != null) await _enqueueListOutbox(_listModelFrom(row));
    });
  }

  // ---- 手动分区（TC-KR-118；元数据 JSON 列，条目 sectionId 挂靠）----

  List<kernel.ReminderSection> _decodeSections(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (m) => kernel.ReminderSection(
                id: m['id'] as String,
                title: m['title'] as String,
                sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
                remoteId: m['remoteId'] as String?,
              ),
            )
            .toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }

  kernel.SmartListFilter? _decodeSmartFilter(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return kernel.SmartListFilter(
          tagEquals: decoded['tagEquals'] as String?,
          flaggedOnly: (decoded['flaggedOnly'] as bool?) ?? false,
        );
      }
    } catch (_) {}
    return null;
  }

  String? _encodeSmartFilter(kernel.SmartListFilter? filter) {
    if (filter == null) return null;
    return jsonEncode({
      'tagEquals': filter.tagEquals,
      'flaggedOnly': filter.flaggedOnly,
    });
  }

  String _encodeSections(List<kernel.ReminderSection> sections) => jsonEncode([
    for (final s in sections)
      {
        'id': s.id,
        'title': s.title,
        'sortOrder': s.sortOrder,
        'remoteId': s.remoteId,
      },
  ]);

  /// 分区排序契约（sortOrder asc, id asc）。
  List<kernel.ReminderSection> _sortedSections(
    List<kernel.ReminderSection> sections,
  ) {
    final list = [...sections]
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    return list;
  }

  Future<void> _writeSections(
    String listId,
    List<kernel.ReminderSection> sections,
  ) async {
    await (_db.update(
      _db.reminderLists,
    )..where((t) => t.id.equals(listId))).write(
      ReminderListsCompanion(
        sectionsJson: Value(_encodeSections(_sortedSections(sections))),
      ),
    );
  }

  @override
  Future<void> upsertSection({
    required String listId,
    required kernel.ReminderSection section,
  }) async {
    final row = await (_db.select(
      _db.reminderLists,
    )..where((t) => t.id.equals(listId))).getSingleOrNull();
    if (row == null) return;
    final sections = [..._decodeSections(row.sectionsJson)];
    final i = sections.indexWhere((e) => e.id == section.id);
    if (i >= 0) {
      sections[i] = section;
    } else {
      sections.add(section);
    }
    await _db.transaction(() async {
      await _writeSections(listId, sections);
      await _enqueueSectionOutbox(
        listId: row.remoteId ?? listId,
        section: section,
      );
    });
  }

  @override
  Future<void> reorderSection({
    required String listId,
    required List<String> sectionIds,
  }) async {
    final row = await (_db.select(
      _db.reminderLists,
    )..where((t) => t.id.equals(listId))).getSingleOrNull();
    if (row == null) return;
    final sections = _decodeSections(row.sectionsJson);
    final byId = {for (final s in sections) s.id: s};
    final ordered = <kernel.ReminderSection>[];
    final seen = <String>{};
    for (final id in sectionIds) {
      final s = byId[id];
      if (s == null || seen.contains(id)) continue;
      seen.add(id);
      ordered.add(s.copyWith(sortOrder: ordered.length));
    }
    for (final s in sections) {
      if (!seen.contains(s.id)) {
        ordered.add(s.copyWith(sortOrder: ordered.length));
      }
    }
    await _db.transaction(() async {
      await _writeSections(listId, ordered);
      for (final s in ordered) {
        await _enqueueSectionOutbox(listId: row.remoteId ?? listId, section: s);
      }
    });
  }

  @override
  Future<void> deleteSection({
    required String listId,
    required String sectionId,
  }) async {
    final row = await (_db.select(
      _db.reminderLists,
    )..where((t) => t.id.equals(listId))).getSingleOrNull();
    if (row == null) return;
    final all = _decodeSections(row.sectionsJson);
    final doomed = all.where((e) => e.id == sectionId).toList(growable: false);
    final sections = all
        .where((e) => e.id != sectionId)
        .toList(growable: false);
    // 级联：挂靠条目兜底「未分区」（drift where 多条件：先查后逐条更新）
    final rows = await (_db.select(
      _db.reminderItems,
    )..where((t) => t.listId.equals(listId) & t.sectionId.isNotNull())).get();
    final targeted = rows
        .where((r) => r.sectionId == sectionId)
        .toList(growable: false);
    for (final r in targeted) {
      await (_db.update(_db.reminderItems)..where((t) => t.id.equals(r.id)))
          .write(const ReminderItemsCompanion(sectionId: Value(null)));
      await _enqueueOutbox([r.id]);
    }
    await _writeSections(listId, sections);
    for (final d in doomed) {
      await _enqueueSectionOutbox(
        listId: row.remoteId ?? listId,
        section: d,
        deleted: true,
      );
    }
  }

  @override
  Future<void> deleteList(String listId) async {
    if (listId.startsWith('smart.')) {
      throw ArgumentError('智能列表不可删除');
    }
    await _db.transaction(() async {
      final doomed = await (_db.select(
        _db.reminderItems,
      )..where((t) => t.listId.equals(listId))).get();
      // 条目随列表进回收窗（软删；TC-UI-109），与 InMemory 同语义
      await (_db.update(_db.reminderItems)
            ..where((t) => t.listId.equals(listId)))
          .write(ReminderItemsCompanion(deletedAt: Value(_now)));
      final gone = await (_db.select(
        _db.reminderLists,
      )..where((t) => t.id.equals(listId))).getSingleOrNull();
      await (_db.delete(
        _db.reminderLists,
      )..where((t) => t.id.equals(listId))).go();
      await _enqueueOutbox([for (final r in doomed) r.id]);
      // flutter#144：清单本体也要出站记 delete（条目级联已各自记过，不重复）
      if (gone != null) {
        await _enqueueListOutbox(_listModelFrom(gone), deleted: true);
      }
    });
  }

  // ---- 内部 ----

  /// 轻量 combineLatest：两侧都有值后，任一侧更新即合并发射。
  static Stream<R> _combineLatest3<A, B, C, R>(
    Stream<A> a,
    Stream<B> b,
    Stream<C> c,
    R Function(A, B, C) combine,
  ) {
    late StreamController<R> controller;
    A? latestA;
    B? latestB;
    C? latestC;
    var hasA = false, hasB = false, hasC = false;
    final subs = <StreamSubscription<dynamic>>[];

    void emit() {
      if (hasA && hasB && hasC) {
        controller.add(combine(latestA as A, latestB as B, latestC as C));
      }
    }

    void listen() {
      subs.add(
        a.listen((v) {
          latestA = v;
          hasA = true;
          emit();
        }),
      );
      subs.add(
        b.listen((v) {
          latestB = v;
          hasB = true;
          emit();
        }),
      );
      subs.add(
        c.listen((v) {
          latestC = v;
          hasC = true;
          emit();
        }),
      );
    }

    controller = StreamController<R>.broadcast(
      onListen: listen,
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
        subs.clear();
        hasA = hasB = hasC = false;
      },
    );
    return controller.stream;
  }

  static Stream<R> _combineLatest2<A, B, R>(
    Stream<A> a,
    Stream<B> b,
    R Function(A, B) combine,
  ) {
    late StreamController<R> controller;
    var hasA = false;
    var hasB = false;
    A? lastA;
    B? lastB;

    void emit() {
      if (hasA && hasB) controller.add(combine(lastA as A, lastB as B));
    }

    controller = StreamController.broadcast(
      onListen: () {
        a.listen((v) {
          lastA = v;
          hasA = true;
          emit();
        });
        b.listen((v) {
          lastB = v;
          hasB = true;
          emit();
        });
      },
    );
    return controller.stream;
  }

  int _count(List<ReminderItem> rows, String listId, DateTime now) {
    if (listId == 'smart.completed' || listId == 'smart.trash') {
      return rows.where((row) => _matches(row, listId, now)).length;
    }
    return rows
        .where((row) => !row.isCompleted && _matches(row, listId, now))
        .length;
  }

  bool _matches(
    ReminderItem row,
    String? listId,
    DateTime now, {
    bool includeCompleted = false,
  }) {
    // 回收窗（TC-UI-109）：软删行只在 smart.trash 出现
    final alive = row.deletedAt == null;
    if (listId == null) return alive;
    return switch (listId) {
      'smart.trash' =>
        row.deletedAt != null &&
            row.deletedAt!.isAfter(
              now.subtract(kernel.InMemoryReminderRepository.recycleWindow),
            ),
      // 今天 = 今天到期 + 已过期未完成（Apple 口径，TC-UI-101）。
      'smart.today' =>
        alive &&
            (includeCompleted || !row.isCompleted) &&
            _isTodayOrOverdue(row.dueAt, now),
      'smart.scheduled' =>
        alive && (includeCompleted || !row.isCompleted) && row.dueAt != null,
      'smart.all' => alive && (includeCompleted || !row.isCompleted),
      'smart.flagged' =>
        alive && (includeCompleted || !row.isCompleted) && row.isFlagged,
      // 紧急 = 已过期未完成或高优先级（含今天已过时）。
      'smart.urgent' =>
        alive &&
            (includeCompleted || !row.isCompleted) &&
            (row.priority >= 9 || _isOverdue(row.dueAt, now)),
      'smart.completed' => alive && row.isCompleted,
      // 分配事项：本地没有 assignee 字段，协作（M4）接入前恒为空。
      'smart.assigned' => false,
      _ => alive && row.listId == listId,
    };
  }

  /// 逾期口径（与 kernel 一致，parity#183）：00:00 = 只有日期，按天比较。
  bool _isOverdue(DateTime? due, DateTime now) {
    if (due == null) return false;
    if (due.hour == 0 && due.minute == 0 && due.second == 0) {
      final day = DateTime(due.year, due.month, due.day);
      return day.isBefore(DateTime(now.year, now.month, now.day));
    }
    return due.isBefore(now);
  }

  bool _isTodayOrOverdue(DateTime? a, DateTime b) {
    if (a == null) return false;
    final day = DateTime(a.year, a.month, a.day);
    final today = DateTime(b.year, b.month, b.day);
    return !day.isAfter(today);
  }

  kernel.ReminderItem _toModel(ReminderItem row) {
    return kernel.ReminderItem(
      id: row.id,
      listId: row.listId,
      title: row.title,
      notes: row.notes,
      isCompleted: row.isCompleted,
      isFlagged: row.isFlagged,
      dueAt: row.dueAt,
      priority: row.priority,
      tags: _decodeTags(row.tags),
      recurrence: row.recurrence,
      recurrenceUntil: row.recurrenceUntil,
      parentId: row.parentId,
      sortOrder: row.sortOrder,
      remoteId: row.remoteId,
      completedAt: row.completedAt,
      sectionId: row.sectionId,
      deletedAt: row.deletedAt,
    );
  }

  ReminderItemsCompanion _companionFrom(kernel.ReminderItem item) {
    return ReminderItemsCompanion.insert(
      id: item.id,
      listId: item.listId,
      title: item.title,
      notes: Value(item.notes),
      isCompleted: Value(item.isCompleted),
      isFlagged: Value(item.isFlagged),
      dueAt: Value(item.dueAt),
      priority: Value(item.priority),
      tags: Value(_encodeTags(item.tags)),
      recurrence: Value(item.recurrence),
      recurrenceUntil: Value(item.recurrenceUntil),
      parentId: Value(item.parentId),
      sortOrder: Value(item.sortOrder),
      remoteId: Value(item.remoteId),
      completedAt: Value(item.completedAt),
      sectionId: Value(item.sectionId),
      deletedAt: Value(item.deletedAt),
    );
  }

  static String _encodeTags(List<String> tags) => jsonEncode(tags);

  static List<String> _decodeTags(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } catch (_) {
      // 容错：损坏数据按空标签处理
    }
    return const [];
  }
}
