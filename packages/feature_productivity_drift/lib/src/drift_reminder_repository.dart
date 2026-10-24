import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;

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
    await _db.into(_db.reminderItems).insertOnConflictUpdate(
          _companionFrom(item),
        );
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
    // 级联删除全部后代（子任务可能多层；SQLite 端已有 FK ON DELETE CASCADE，
    // 但外键需 PRAGMA 开启，这里显式应用层级联保证内存/Drift 行为一致）
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
    await (_db.delete(_db.reminderItems)
          ..where((t) => t.id.isIn(removed)))
        .go();
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

  @override
  Future<void> deleteList(String listId) async {
    if (listId.startsWith('smart.')) {
      throw ArgumentError('智能列表不可删除');
    }
    await _db.transaction(() async {
      await (_db.delete(_db.reminderItems)
            ..where((t) => t.listId.equals(listId)))
          .go();
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
    if (listId == null) return true;
    return switch (listId) {
      'smart.today' => !row.isCompleted && _isSameLocalDay(row.dueAt, now),
      'smart.scheduled' => !row.isCompleted && row.dueAt != null,
      'smart.all' => !row.isCompleted,
      'smart.flagged' => !row.isCompleted && row.isFlagged,
      'smart.urgent' => !row.isCompleted &&
          (row.priority >= 9 ||
              (row.dueAt != null &&
                  !row.dueAt!.isAfter(now) &&
                  _isSameLocalDay(row.dueAt, now))),
      'smart.completed' => row.isCompleted,
      _ => row.listId == listId,
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
