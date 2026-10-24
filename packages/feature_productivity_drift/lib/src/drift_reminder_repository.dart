import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart'
    show OrderingTerm, Value, BooleanExpressionOperators;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;

import 'db.dart';

/// [kernel.ReminderRepository] 的 Drift 实现（离线持久化）。
///
/// - `watch*` 基于 drift 响应式 watch 流，写操作自动推送新快照
/// - 编辑语义（Phase 2 拍板）：全字段编辑 = copyWith + upsertItem 全量回写；
///   toggle 留仓库层（防读改写丢更新 + 重复滚动）；删除为级联语义动作
/// - 智能列表语义过滤与 InMemory 实现一致；排序契约 `sortOrder asc, id asc`
/// - UI 不接触 drift 类型：本包只向端口吐 kernel 实体
class DriftReminderRepository implements kernel.ReminderRepository {
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
    kernel.ReminderList(id: 'smart.flagged', title: '已旗标', isSmart: true),
    kernel.ReminderList(id: 'smart.urgent', title: '紧急', isSmart: true),
    kernel.ReminderList(id: 'smart.completed', title: '完成', isSmart: true),
    kernel.ReminderList(id: 'smart.trash', title: '最近删除', isSmart: true),
  ];

  @override
  Stream<List<kernel.ReminderList>> watchLists() {
    final lists$ = _db.select(_db.reminderLists).watch();
    final items$ = _db.select(_db.reminderItems).watch();
    return _combineLatest2<List<ReminderList>, List<ReminderItem>,
        List<kernel.ReminderList>>(lists$, items$, (listRows, itemRows) {
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
          ),
      ];
    });
  }

  @override
  Stream<List<kernel.ReminderItem>> watchItems({String? listId}) {
    final now = _now;
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
    return query.watch().map(
      (rows) => List<kernel.ReminderItem>.unmodifiable(
        rows
            .where((row) => _matches(row, listId, now))
            .map(_toModel)
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<void> upsertItem(kernel.ReminderItem item) async {
    if (item.id.startsWith('smart.')) {
      throw ArgumentError('smart. 前缀保留给智能列表派生，禁止作为条目 id');
    }
    // 防复活（cursor PR#12）：软删行只经 restoreItem 恢复；
    // 对已删条目的全量回写（deletedAt 丢失）保留回收窗标记
    final existing = await (_db.select(_db.reminderItems)
          ..where((t) => t.id.equals(item.id)))
        .getSingleOrNull();
    await _db.into(_db.reminderItems).insertOnConflictUpdate(
          _companionFrom(item),
        );
    if (existing != null &&
        existing.deletedAt != null &&
        item.deletedAt == null) {
      await (_db.update(_db.reminderItems)
            ..where((t) => t.id.equals(item.id)))
          .write(
              ReminderItemsCompanion(deletedAt: Value(existing.deletedAt)));
    }
  }

  @override
  Future<void> toggleCompleted(String itemId) async {
    await _db.transaction(() async {
      final row = await (_db.select(_db.reminderItems)
            ..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();
      if (row == null) return;
      final cur = _toModel(row);
      final rule = cur.recurrenceRule;
      if (rule != null && !cur.isCompleted && cur.dueAt != null) {
        // 完成带重复规则的条目：滚动下一次 dueAt，完成态回 false
        final next = rule.nextOccurrence(cur.dueAt!, _now);
        await (_db.update(_db.reminderItems)
              ..where((t) => t.id.equals(itemId)))
            .write(ReminderItemsCompanion(
          dueAt: Value(next),
          isCompleted: const Value(false),
          completedAt: const Value(null),
        ));
      } else {
        // 完成时间联动（服务端 completedAt 对齐）：完成记当下，取消清空
        await (_db.update(_db.reminderItems)
              ..where((t) => t.id.equals(itemId)))
            .write(ReminderItemsCompanion(
          isCompleted: Value(!cur.isCompleted),
          completedAt:
              Value(!cur.isCompleted ? _now : null),
        ));
      }
    });
  }

  @override
  Future<void> toggleFlagged(String itemId) async {
    await _db.transaction(() async {
      final row = await (_db.select(_db.reminderItems)
            ..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();
      if (row == null) return;
      await (_db.update(_db.reminderItems)
            ..where((t) => t.id.equals(itemId)))
          .write(
              ReminderItemsCompanion(isFlagged: Value(!row.isFlagged)));
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
          await (_db.update(_db.reminderItems)
                ..where((t) => t.id.equals(r.id)))
              .write(ReminderItemsCompanion(
            listId: Value(targetListId),
            sectionId: const Value(null), // 分区随列表（TC-API-118）
          ));
        }
      }
    });
  }

  @override
  Future<void> deleteItem(String itemId) async {
    // 软删级联（TC-UI-109）：本条 + 后代进 30 天回收窗（与 InMemory 同语义）
    final cascade = await _cascadeFrom(itemId);
    await (_db.update(_db.reminderItems)
          ..where((t) => t.id.isIn(cascade)))
        .write(ReminderItemsCompanion(deletedAt: Value(_now)));
  }

  @override
  Future<void> restoreItem(String itemId) async {
    await _db.transaction(() async {
      final cascade = await _cascadeFrom(itemId);
      final target = await (_db.select(_db.reminderItems)
            ..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();
      if (target == null) return;
      final lists = await _db.select(_db.reminderLists).get();
      final listAlive =
          lists.any((l) => l.id == target.listId && !l.isSmart);
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
        await (_db.update(_db.reminderItems)
              ..where((t) => t.id.isIn(cascade)))
            .write(ReminderItemsCompanion(
                listId: Value(fallback), deletedAt: const Value(null)));
      } else {
        await (_db.update(_db.reminderItems)
              ..where((t) => t.id.isIn(cascade)))
            .write(
                const ReminderItemsCompanion(deletedAt: Value(null)));
      }
    });
  }

  @override
  Future<int> purgeExpiredDeleted() async {
    final cutoff =
        _now.subtract(kernel.InMemoryReminderRepository.recycleWindow);
    // 查后删：避免 drift 版本比较方法差异，语义与 InMemory 一致
    final rows = await _db.select(_db.reminderItems).get();
    final expired = rows
        .where((r) =>
            r.deletedAt != null && r.deletedAt!.isBefore(cutoff))
        .map((r) => r.id)
        .toSet();
    if (expired.isEmpty) return 0;
    return await (_db.delete(_db.reminderItems)
          ..where((t) => t.id.isIn(expired)))
        .go();
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

  @override
  Future<void> upsertList(kernel.ReminderList list) async {
    if (list.id.startsWith('smart.')) {
      throw ArgumentError('smart. 前缀保留给智能列表，禁止用户数据占用');
    }
    await _db.into(_db.reminderLists).insertOnConflictUpdate(
          ReminderListsCompanion.insert(
            id: list.id,
            title: list.title,
            colorArgb: Value(list.colorArgb),
            sortOrder: Value(list.sortOrder),
          ),
        );
  }

  // ---- 手动分区（TC-KR-118；元数据 JSON 列，条目 sectionId 挂靠）----

  List<kernel.ReminderSection> _decodeSections(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => kernel.ReminderSection(
                  id: m['id'] as String,
                  title: m['title'] as String,
                  sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
                ))
            .toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }

  String _encodeSections(List<kernel.ReminderSection> sections) =>
      jsonEncode([
        for (final s in sections)
          {'id': s.id, 'title': s.title, 'sortOrder': s.sortOrder},
      ]);

  /// 分区排序契约（sortOrder asc, id asc）。
  List<kernel.ReminderSection> _sortedSections(
    List<kernel.ReminderSection> sections,
  ) {
    final list = [...sections]..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    return list;
  }

  Future<void> _writeSections(
    String listId,
    List<kernel.ReminderSection> sections,
  ) async {
    await (_db.update(_db.reminderLists)
          ..where((t) => t.id.equals(listId)))
        .write(ReminderListsCompanion(
      sectionsJson: Value(_encodeSections(_sortedSections(sections))),
    ));
  }

  @override
  Future<void> upsertSection({
    required String listId,
    required kernel.ReminderSection section,
  }) async {
    final row = await (_db.select(_db.reminderLists)
          ..where((t) => t.id.equals(listId)))
        .getSingleOrNull();
    if (row == null) return;
    final sections = [..._decodeSections(row.sectionsJson)];
    final i = sections.indexWhere((e) => e.id == section.id);
    if (i >= 0) {
      sections[i] = section;
    } else {
      sections.add(section);
    }
    await _writeSections(listId, sections);
  }

  @override
  Future<void> reorderSection({
    required String listId,
    required List<String> sectionIds,
  }) async {
    final row = await (_db.select(_db.reminderLists)
          ..where((t) => t.id.equals(listId)))
        .getSingleOrNull();
    if (row == null) return;
    final sections = _decodeSections(row.sectionsJson);
    final byId = {
      for (final s in sections) s.id: s,
    };
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
    await _writeSections(listId, ordered);
  }

  @override
  Future<void> deleteSection({
    required String listId,
    required String sectionId,
  }) async {
    final row = await (_db.select(_db.reminderLists)
          ..where((t) => t.id.equals(listId)))
        .getSingleOrNull();
    if (row == null) return;
    final sections = _decodeSections(row.sectionsJson)
        .where((e) => e.id != sectionId)
        .toList(growable: false);
    // 级联：挂靠条目兜底「未分区」（drift where 多条件：先查后逐条更新）
    final rows = await (_db.select(_db.reminderItems)
          ..where((t) => t.listId.equals(listId) & t.sectionId.isNotNull()))
        .get();
    final targeted =
        rows.where((r) => r.sectionId == sectionId).toList(growable: false);
    for (final r in targeted) {
      await (_db.update(_db.reminderItems)
            ..where((t) => t.id.equals(r.id)))
          .write(const ReminderItemsCompanion(sectionId: Value(null)));
    }
    await _writeSections(listId, sections);
  }

  @override
  Future<void> deleteList(String listId) async {
    if (listId.startsWith('smart.')) {
      throw ArgumentError('智能列表不可删除');
    }
    await _db.transaction(() async {
      // 条目随列表进回收窗（软删；TC-UI-109），与 InMemory 同语义
      await (_db.update(_db.reminderItems)
            ..where((t) => t.listId.equals(listId)))
          .write(ReminderItemsCompanion(deletedAt: Value(_now)));
      await (_db.delete(_db.reminderLists)
            ..where((t) => t.id.equals(listId)))
          .go();
    });
  }

  // ---- 内部 ----

  /// 轻量 combineLatest：两侧都有值后，任一侧更新即合并发射。
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
    if (listId == 'smart.completed') {
      return rows.where((row) => _matches(row, listId, now)).length;
    }
    return rows
        .where((row) => !row.isCompleted && _matches(row, listId, now))
        .length;
  }

  bool _matches(ReminderItem row, String? listId, DateTime now) {
    // 回收窗（TC-UI-109）：软删行只在 smart.trash 出现
    final alive = row.deletedAt == null;
    if (listId == null) return alive;
    return switch (listId) {
      'smart.trash' =>
        row.deletedAt != null &&
            row.deletedAt!.isAfter(now.subtract(
                kernel.InMemoryReminderRepository.recycleWindow)),
      'smart.today' =>
        alive && !row.isCompleted && _isSameLocalDay(row.dueAt, now),
      'smart.scheduled' => alive && !row.isCompleted && row.dueAt != null,
      'smart.all' => alive && !row.isCompleted,
      'smart.flagged' => alive && !row.isCompleted && row.isFlagged,
      'smart.urgent' => alive &&
          !row.isCompleted &&
          (row.priority >= 9 ||
              (row.dueAt != null &&
                  !row.dueAt!.isAfter(now) &&
                  _isSameLocalDay(row.dueAt, now))),
      'smart.completed' => alive && row.isCompleted,
      _ => alive && row.listId == listId,
    };
  }

  bool _isSameLocalDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
