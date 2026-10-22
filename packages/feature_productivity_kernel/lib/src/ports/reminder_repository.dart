import 'dart:async';

import '../models/recurrence.dart';
import '../models/reminder_item.dart';
import '../models/reminder_list.dart';

/// 提醒数据端口。
///
/// 编辑语义（Phase 2 拍板）：
/// - 全字段编辑 = UI 层 `copyWith` + [upsertItem] 全量回写（端口不设字段级 setter）
/// - `toggle*` 留在仓库层：防读-改-写丢更新，且 [toggleCompleted] 须承载重复规则滚动
/// - 删除为语义动作（级联删除子任务/列表条目）
///
/// `watch*` 返回 [Stream]：任何写操作后订阅方收到新快照，UI 用
/// Riverpod StreamProvider 消费，禁止手动 reload 循环。
abstract interface class ReminderRepository {
  /// 全部列表（智能 + 我的）；首帧后随写操作推送新值。
  Stream<List<ReminderList>> watchLists();

  /// 条目查询；[listId] 为空 = 全部。
  ///
  /// 返回该列表**全部层级**（顶层 + 子任务），由 UI 纯函数分组渲染；
  /// 排序契约统一 `sortOrder asc, id asc`。
  /// 智能列表 id（`smart.` 前缀）按语义过滤（子任务同样生效）：
  /// - `smart.today`：未完成且 dueAt 在今天内
  /// - `smart.scheduled`：未完成且带 dueAt
  /// - `smart.all`：未完成全部
  /// - `smart.flagged`：未完成且 isFlagged
  Stream<List<ReminderItem>> watchItems({String? listId});

  /// 新增或更新单条提醒（全字段回写；id 用 [newReminderId] 工厂生成）。
  Future<void> upsertItem(ReminderItem item);

  /// 切换完成态。
  ///
  /// 带重复规则的条目在完成时**滚动**：dueAt = nextOccurrence、
  /// isCompleted 回 false（对齐 Apple 提醒事项「完成即生成下一次」）。
  Future<void> toggleCompleted(String itemId);

  /// 切换旗标态。
  Future<void> toggleFlagged(String itemId);

  /// 删除单条提醒（级联删除其全部子任务）。
  Future<void> deleteItem(String itemId);

  /// 新增或更新列表（我的列表）。
  ///
  /// id 用 [newListId] 工厂生成；禁止 `smart.` 前缀（智能列表非用户数据）。
  Future<void> upsertList(ReminderList list);

  /// 删除列表（级联删除其全部条目）。
  Future<void> deleteList(String listId);
}

/// 内存实现：壳层与 UI 冒烟 + 仓库契约测试的参考实现。
final class InMemoryReminderRepository implements ReminderRepository {
  InMemoryReminderRepository({bool seedSampleData = true}) {
    if (!seedSampleData) return;
    _lists.addAll(const [
      ReminderList(
        id: 'smart.today',
        title: '今天',
        isSmart: true,
        itemCount: 2,
      ),
      ReminderList(
        id: 'smart.scheduled',
        title: '计划',
        isSmart: true,
        itemCount: 1,
      ),
      ReminderList(
        id: 'smart.all',
        title: '全部',
        isSmart: true,
        itemCount: 3,
      ),
      ReminderList(
        id: 'smart.flagged',
        title: '已旗标',
        isSmart: true,
        itemCount: 1,
      ),
      ReminderList(
        id: 'list.personal',
        title: '个人',
        colorArgb: 0xFF34C759,
        itemCount: 2,
      ),
      ReminderList(
        id: 'list.work',
        title: '工作',
        colorArgb: 0xFFFF9500,
        itemCount: 1,
      ),
    ]);
    final now = DateTime.now();
    _items.addAll([
      ReminderItem(
        id: '1',
        listId: 'list.personal',
        title: '买牛奶',
        isFlagged: true,
        dueAt: now,
      ),
      ReminderItem(
        id: '2',
        listId: 'list.personal',
        title: '写 LifeOS 基建',
        dueAt: now,
      ),
      const ReminderItem(
        id: '3',
        listId: 'list.work',
        title: '评审提醒事项线框',
        priority: 5,
      ),
    ]);
    _recount();
  }

  final _lists = <ReminderList>[];
  final _items = <ReminderItem>[];
  final _listWatchers = <_ListsWatcher>[];
  final _itemWatchers = <_ItemsWatcher>[];
  DateTime? _nowForTest;

  /// 测试注入「当前时间」以冻结今天边界。
  set nowForTest(DateTime? value) => _nowForTest = value;

  DateTime get _now => _nowForTest ?? DateTime.now();

  @override
  Stream<List<ReminderList>> watchLists() {
    final watcher = _ListsWatcher();
    _listWatchers.add(watcher);
    final stream = watcher.stream(onListen: () => _emitLists(watcher));
    watcher.whenCanceled(() => _listWatchers.remove(watcher));
    return stream;
  }

  @override
  Stream<List<ReminderItem>> watchItems({String? listId}) {
    final watcher = _ItemsWatcher(listId);
    _itemWatchers.add(watcher);
    final stream = watcher.stream(onListen: () => _emitItems(watcher));
    watcher.whenCanceled(() => _itemWatchers.remove(watcher));
    return stream;
  }

  @override
  Future<void> upsertItem(ReminderItem item) async {
    if (item.id.startsWith('smart.')) {
      throw ArgumentError('smart. 前缀保留给智能列表派生，禁止作为条目 id');
    }
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i >= 0) {
      _items[i] = item;
    } else {
      _items.add(item);
    }
    _recount();
    _notify();
  }

  @override
  Future<void> toggleCompleted(String itemId) async {
    final i = _items.indexWhere((e) => e.id == itemId);
    if (i < 0) return;
    final cur = _items[i];
    final rule = cur.recurrenceRule;
    if (rule != null && !cur.isCompleted && cur.dueAt != null) {
      // 完成带重复规则的条目：滚动下一次 dueAt，完成态回 false
      final next = rule.nextOccurrence(cur.dueAt!, _now);
      _items[i] = cur.copyWith(dueAt: next, isCompleted: false);
    } else {
      _items[i] = cur.copyWith(isCompleted: !cur.isCompleted);
    }
    _recount();
    _notify();
  }

  @override
  Future<void> toggleFlagged(String itemId) async {
    final i = _items.indexWhere((e) => e.id == itemId);
    if (i < 0) return;
    final cur = _items[i];
    _items[i] = cur.copyWith(isFlagged: !cur.isFlagged);
    _notify();
  }

  @override
  Future<void> deleteItem(String itemId) async {
    // 级联删除全部后代（子任务可能多层）
    final removed = <String>{itemId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final e in _items) {
        if (e.parentId != null && removed.contains(e.parentId) &&
            !removed.contains(e.id)) {
          removed.add(e.id);
          changed = true;
        }
      }
    }
    _items.removeWhere((e) => removed.contains(e.id));
    _recount();
    _notify();
  }

  @override
  Future<void> upsertList(ReminderList list) async {
    if (list.id.startsWith('smart.')) {
      throw ArgumentError('smart. 前缀保留给智能列表，禁止用户数据占用');
    }
    final i = _lists.indexWhere((e) => e.id == list.id);
    if (i >= 0) {
      _lists[i] = list;
    } else {
      _lists.add(list);
    }
    _recount();
    _notify();
  }

  @override
  Future<void> deleteList(String listId) async {
    if (listId.startsWith('smart.')) {
      throw ArgumentError('智能列表不可删除');
    }
    _lists.removeWhere((e) => e.id == listId);
    _items.removeWhere((e) => e.listId == listId);
    _notify();
  }

  // ---- 内部 ----

  /// 未完成计数回写（智能 + 我的列表均按未完成条数计）。
  void _recount() {
    final now = _now;
    for (var i = 0; i < _lists.length; i++) {
      final list = _lists[i];
      final count = _filter(list.id, now).where((e) => !e.isCompleted).length;
      _lists[i] = list.copyWith(itemCount: count);
    }
  }

  void _notify() {
    final lists = List<ReminderList>.unmodifiable(_lists);
    for (final w in _listWatchers.toList(growable: false)) {
      w.controller.add(lists);
    }
    for (final w in _itemWatchers.toList(growable: false)) {
      w.controller.add(_snapshotItems(w.listId));
    }
  }

  void _emitLists(_ListsWatcher watcher) {
    watcher.controller.add(List<ReminderList>.unmodifiable(_lists));
  }

  void _emitItems(_ItemsWatcher watcher) {
    watcher.controller.add(_snapshotItems(watcher.listId));
  }

  List<ReminderItem> _snapshotItems(String? listId) =>
      List<ReminderItem>.unmodifiable(_sorted(_filter(listId, _now)));

  /// 排序契约（两实现一致）：`sortOrder asc, id asc`。
  List<ReminderItem> _sorted(Iterable<ReminderItem> items) {
    final list = items.toList(growable: false)
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    return list;
  }

  Iterable<ReminderItem> _filter(String? listId, DateTime now) {
    if (listId == null) return _items;
    return switch (listId) {
      'smart.today' => _items.where(
          (e) => !e.isCompleted && _isSameLocalDay(e.dueAt, now)),
      'smart.scheduled' =>
          _items.where((e) => !e.isCompleted && e.dueAt != null),
      'smart.all' => _items.where((e) => !e.isCompleted),
      'smart.flagged' => _items.where((e) => !e.isCompleted && e.isFlagged),
      _ => _items.where((e) => e.listId == listId),
    };
  }

  bool _isSameLocalDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// 订阅包装：广播流，由仓库在 cancel 时注销，避免泄漏。
final class _RepoWatch<T> {
  final controller = StreamController<T>.broadcast();
  final List<void Function()> onCancelCallbacks = [];

  Stream<T> stream({required void Function() onListen}) {
    controller
      ..onListen = onListen
      ..onCancel = () {
        for (final cb in onCancelCallbacks) {
          cb();
        }
      };
    return controller.stream;
  }

  void whenCanceled(void Function() cb) => onCancelCallbacks.add(cb);
}

/// 列表订阅（无参数）。
final class _ListsWatcher extends _RepoWatch<List<ReminderList>> {}

/// 条目订阅（按 listId 过滤）。
final class _ItemsWatcher extends _RepoWatch<List<ReminderItem>> {
  _ItemsWatcher(this.listId);

  final String? listId;
}
