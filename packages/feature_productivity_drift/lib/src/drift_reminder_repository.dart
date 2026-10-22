import 'dart:async';

import 'package:drift/drift.dart'
    show OrderingTerm, OrderingMode, NullsOrder, Value;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;

import 'db.dart';

/// [kernel.ReminderRepository] 的 Drift 实现（离线持久化）。
///
/// - `watch*` 基于 drift 响应式 watch 流，写操作自动推送新快照
/// - 智能列表语义过滤与 InMemory 实现一致（今天/计划/全部/旗标）
/// - 未完成计数由查询派生，回写列表快照 itemCount
/// - UI 不接触 drift 类型：本包只向端口吐 kernel 实体
class DriftReminderRepository implements kernel.ReminderRepository {
  DriftReminderRepository(this._db);

  final LifeProductivityDb _db;

  /// 智能列表元数据（不落表，watchLists 派生时合并）。
  static const List<kernel.ReminderList> smartLists = [
    kernel.ReminderList(id: 'smart.today', title: '今天', isSmart: true),
    kernel.ReminderList(id: 'smart.scheduled', title: '计划', isSmart: true),
    kernel.ReminderList(id: 'smart.all', title: '全部', isSmart: true),
    kernel.ReminderList(id: 'smart.flagged', title: '已旗标', isSmart: true),
  ];

  @override
  Stream<List<kernel.ReminderList>> watchLists() {
    final lists$ = _db.select(_db.reminderLists).watch();
    final items$ = _db.select(_db.reminderItems).watch();
    return _combineLatest2<
        List<ReminderList>,
        List<ReminderItem>,
        List<kernel.ReminderList>>(lists$, items$, (listRows, itemRows) {
      final now = _now();
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
          ),
      ];
    });
  }

  @override
  Stream<List<kernel.ReminderItem>> watchItems({String? listId}) {
    final now = _now();
    final query = _db.select(_db.reminderItems)
      ..orderBy([
        (t) => OrderingTerm(
              expression: t.dueAt,
              nulls: NullsOrder.first,
              mode: OrderingMode.desc,
            ),
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
    await _db
        .into(_db.reminderItems)
        .insertOnConflictUpdate(_companionFrom(item));
  }

  @override
  Future<void> toggleCompleted(String itemId) async {
    final row = await (_db.select(_db.reminderItems)
          ..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.reminderItems)
          ..where((t) => t.id.equals(itemId)))
        .write(ReminderItemsCompanion(isCompleted: Value(!row.isCompleted)));
  }

  @override
  Future<void> upsertList(kernel.ReminderList list) async {
    await _db.into(_db.reminderLists).insertOnConflictUpdate(
          ReminderListsCompanion.insert(
            id: list.id,
            title: list.title,
            colorArgb: Value(list.colorArgb),
          ),
        );
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

  DateTime _now() => DateTime.now();

  int _count(List<ReminderItem> rows, String listId, DateTime now) {
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
    );
  }
}
