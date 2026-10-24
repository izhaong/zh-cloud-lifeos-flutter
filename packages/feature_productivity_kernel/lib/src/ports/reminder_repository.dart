import 'dart:async';

import '../models/recurrence.dart';
import '../models/reminder_item.dart';
import '../models/reminder_list.dart';
import '../models/reminder_section.dart';

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
  /// - `smart.urgent`：未完成且（当日过期 或 priority>=9）
  /// - `smart.completed`：已完成全部（模型 D2 预留入口）
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

  /// 移动提醒到其他列表（TC-UI-119 / TC-API-118 同口径：分区随列表，跨列表必清空；
  /// 子任务随父一起移动）。
  Future<void> moveItem(String itemId, String targetListId);

  /// 删除单条提醒（级联其全部子任务）——软删：进「最近删除」30 天回收窗
  /// （deletedAt；TC-UI-109/TC-API-110 本地侧），窗口外由 [purgeExpiredDeleted] 硬清。
  Future<void> deleteItem(String itemId);

  /// 从「最近删除」恢复：清本条及其后代 deletedAt；原列表已删则落首个自有列表。
  Future<void> restoreItem(String itemId);

  /// 硬删回收窗超期（>30 天）条目，返回清理条数。
  Future<int> purgeExpiredDeleted();

  /// 新增或更新列表（我的列表）。
  ///
  /// id 用 [newListId] 工厂生成；禁止 `smart.` 前缀（智能列表非用户数据）。
  Future<void> upsertList(ReminderList list);

  /// 删除列表（级联删除其全部条目）。
  Future<void> deleteList(String listId);

  /// 新增/更新手动分区元数据（TC-KR-118）。
  Future<void> upsertSection({
    required String listId,
    required ReminderSection section,
  });

  /// 分区保序重排（[sectionIds] 为目标全序；normalize 滤未知 id）。
  Future<void> reorderSection({
    required String listId,
    required List<String> sectionIds,
  });

  /// 删除分区（级联：挂靠条目 sectionId 清空，兜底「未分区」）。
  Future<void> deleteSection({
    required String listId,
    required String sectionId,
  });
}

/// 内存实现：壳层与 UI 冒烟 + 仓库契约测试的参考实现。
final class InMemoryReminderRepository implements ReminderRepository {
  /// 智能列表元数据（恒在；不随种子开关）。
  static const List<ReminderList> smartListMeta = [
    ReminderList(id: 'smart.today', title: '今天', isSmart: true),
    ReminderList(id: 'smart.scheduled', title: '计划', isSmart: true),
    ReminderList(id: 'smart.all', title: '全部', isSmart: true),
    ReminderList(id: 'smart.flagged', title: '已旗标', isSmart: true),
    ReminderList(id: 'smart.urgent', title: '紧急', isSmart: true),
    ReminderList(id: 'smart.completed', title: '完成', isSmart: true),
    ReminderList(id: 'smart.trash', title: '最近删除', isSmart: true),
  ];

  /// 回收窗时长（Apple 口径 30 天）。
  static const Duration recycleWindow = Duration(days: 30);
  InMemoryReminderRepository({bool seedSampleData = true}) {
    // 智能列表元数据恒在（不依赖种子开关；与 Drift smartLists 派生一致）
    _lists.addAll(smartListMeta);
    if (!seedSampleData) return;
    _lists.addAll(const [
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
  final _sectionsByList = <String, List<ReminderSection>>{};
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
      // 防复活（cursor PR#12）：软删行只经 restoreItem 恢复；
      // 已删条目被全量回写（deletedAt 丢失）时保留回收窗标记
      final existing = _items[i];
      _items[i] = existing.deletedAt != null && item.deletedAt == null
          ? _copyWithDeletedAt(item, existing.deletedAt!)
          : item;
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
      _items[i] = cur.copyWith(
          dueAt: next, isCompleted: false, completedAt: ReminderItem.clear);
    } else {
      // 完成时间联动（服务端 completedAt 对齐）：完成记当下，取消清空
      _items[i] = cur.copyWith(
        isCompleted: !cur.isCompleted,
        completedAt: !cur.isCompleted ? _now : ReminderItem.clear,
      );
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
  Future<void> moveItem(String itemId, String targetListId) async {
    if (!_items.any((e) => e.id == itemId) ||
        !_lists.any((l) => l.id == targetListId && !l.isSmart)) {
      return;
    }
    for (var i = 0; i < _items.length; i++) {
      final e = _items[i];
      // 本条或其后代（子任务随父）→ 换列表并清分区
      final selfOrDescendant =
          e.id == itemId || _isDescendantOf(e.id, itemId);
      if (selfOrDescendant) {
        _items[i] = ReminderItem(
          id: e.id,
          listId: targetListId,
          title: e.title,
          notes: e.notes,
          isCompleted: e.isCompleted,
          isFlagged: e.isFlagged,
          dueAt: e.dueAt,
          priority: e.priority,
          tags: e.tags,
          recurrence: e.recurrence,
          parentId: e.parentId,
          sortOrder: e.sortOrder,
          remoteId: e.remoteId,
          completedAt: e.completedAt,
          sectionId: null,
          deletedAt: e.deletedAt,
        );
      }
    }
    _recount();
    _notify();
  }

  bool _isDescendantOf(String id, String ancestorId) {
    ReminderItem? byId(String? iid) {
      for (final e in _items) {
        if (e.id == iid) return e;
      }
      return null;
    }

    var cursor = byId(id);
    for (var depth = 0; depth < 64 && cursor != null; depth++) {
      if (cursor.parentId == ancestorId) return true;
      cursor = byId(cursor.parentId);
    }
    return false;
  }

  @override
  Future<void> deleteItem(String itemId) async {
    // 软删级联（TC-UI-109）：本条 + 全部后代进 30 天回收窗
    final cascade = _cascadeFrom(itemId);
    for (var i = 0; i < _items.length; i++) {
      if (cascade.contains(_items[i].id)) {
        _items[i] = _copyWithDeletedAt(_items[i], _now);
      }
    }
    _recount();
    _notify();
  }

  @override
  Future<void> restoreItem(String itemId) async {
    final cascade = _cascadeFrom(itemId);
    // 原列表已删 ⇒ 落首个自有列表（Apple 默认列表口径）
    final target = _items.firstWhere((e) => e.id == itemId);
    final listAlive =
        _lists.any((l) => l.id == target.listId && !l.isSmart);
    String? fallback;
    if (!listAlive) {
      for (final l in _lists) {
        if (!l.isSmart) {
          fallback = l.id;
          break;
        }
      }
    }
    for (var i = 0; i < _items.length; i++) {
      final e = _items[i];
      if (!cascade.contains(e.id)) continue;
      _items[i] = ReminderItem(
        id: e.id,
        listId: fallback ?? e.listId,
        title: e.title,
        notes: e.notes,
        isCompleted: e.isCompleted,
        isFlagged: e.isFlagged,
        dueAt: e.dueAt,
        priority: e.priority,
        tags: e.tags,
        recurrence: e.recurrence,
        parentId: e.parentId,
        sortOrder: e.sortOrder,
        remoteId: e.remoteId,
        completedAt: e.completedAt,
        sectionId: e.sectionId,
      ); // deletedAt 置空
    }
    _recount();
    _notify();
  }

  @override
  Future<int> purgeExpiredDeleted() async {
    final cutoff = _now.subtract(recycleWindow);
    final before = _items.length;
    _items.removeWhere(
        (e) => e.deletedAt != null && !e.deletedAt!.isAfter(cutoff));
    final removed = before - _items.length;
    if (removed > 0) {
      _recount();
      _notify();
    }
    return removed;
  }

  /// 本条 + 全部后代（子任务可能多层）。
  Set<String> _cascadeFrom(String itemId) {
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
    return removed;
  }

  ReminderItem _copyWithDeletedAt(ReminderItem e, DateTime at) {
    return ReminderItem(
      id: e.id,
      listId: e.listId,
      title: e.title,
      notes: e.notes,
      isCompleted: e.isCompleted,
      isFlagged: e.isFlagged,
      dueAt: e.dueAt,
      priority: e.priority,
      tags: e.tags,
      recurrence: e.recurrence,
      parentId: e.parentId,
      sortOrder: e.sortOrder,
      remoteId: e.remoteId,
      completedAt: e.completedAt,
      sectionId: e.sectionId,
      deletedAt: at,
    );
  }

  @override
  Future<void> upsertList(ReminderList list) async {
    if (list.id.startsWith('smart.')) {
      // TC-UI-116：smart.custom.* 为用户自建智能列表（合法）；
      // 仅内置五预设 + trash 由仓库派生，不得被用户数据占用/篡改。
      if (!list.id.startsWith('smart.custom.')) {
        throw ArgumentError('smart. 前缀保留给智能列表，禁止用户数据占用');
      }
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
    // 条目随列表进回收窗（软删）；列表本身移除
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].listId == listId) {
        _items[i] = _copyWithDeletedAt(_items[i], _now);
      }
    }
    _lists.removeWhere((l) => l.id == listId);
    // 分区元数据随列表清理（防同 id 重建列表出现幽灵分区；cursor PR#14 非阻断3）
    _sectionsByList.remove(listId);
    _recount();
    _notify();
  }

  @override
  Future<void> upsertSection({
    required String listId,
    required ReminderSection section,
  }) async {
    final sections =
        _sectionsByList.putIfAbsent(listId, () => []);
    final i = sections.indexWhere((e) => e.id == section.id);
    if (i >= 0) {
      sections[i] = section;
    } else {
      sections.add(section);
    }
    _syncSectionsToList(listId);
    _notify();
  }

  @override
  Future<void> reorderSection({
    required String listId,
    required List<String> sectionIds,
  }) async {
    final sections = _sectionsByList[listId];
    if (sections == null) return;
    // 保序重排：滤未知 id；已知分区缺列保底追加在尾
    final byId = {
      for (final s in sections) s.id: s,
    };
    final ordered = <ReminderSection>[];
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
    _sectionsByList[listId] = ordered;
    _syncSectionsToList(listId);
    _notify();
  }

  @override
  Future<void> deleteSection({
    required String listId,
    required String sectionId,
  }) async {
    _sectionsByList[listId]?.removeWhere((e) => e.id == sectionId);
    // 级联：挂靠条目兜底「未分区」
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it.listId == listId &&
          it.sectionId == sectionId &&
          it.sectionId != null) {
        _items[i] = it.copyWith(sectionId: ReminderItem.clear);
      }
    }
    _syncSectionsToList(listId);
    _recount();
    _notify();
  }

  /// 分区元数据同步到列表快照（排序契约 sortOrder asc, id asc）。
  void _syncSectionsToList(String listId) {
    final i = _lists.indexWhere((e) => e.id == listId);
    if (i < 0) return;
    final sections = [...?_sectionsByList[listId]]..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    _lists[i] = _lists[i].copyWith(sections: sections);
  }

  // ---- 内部 ----

  /// 未完成计数回写（智能 + 我的列表均按未完成条数计）。
  void _recount() {
    final now = _now;
    for (var i = 0; i < _lists.length; i++) {
      final list = _lists[i];
      final count = list.id == 'smart.completed'
          ? _filter(list.id, now).length
          : _filter(list.id, now).where((e) => !e.isCompleted).length;
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
    // 回收窗（TC-UI-109）：软删条目只在 smart.trash 出现
    final alive = _items.where((e) => e.deletedAt == null);
    if (listId == null) return alive;
    return switch (listId) {
      'smart.trash' => _items.where((e) =>
          e.deletedAt != null &&
          e.deletedAt!.isAfter(now.subtract(recycleWindow))),
      'smart.today' => alive.where(
          (e) => !e.isCompleted && _isSameLocalDay(e.dueAt, now)),
      'smart.scheduled' =>
          alive.where((e) => !e.isCompleted && e.dueAt != null),
      'smart.all' => alive.where((e) => !e.isCompleted),
      'smart.flagged' => alive.where((e) => !e.isCompleted && e.isFlagged),
      'smart.urgent' => alive.where((e) =>
          !e.isCompleted &&
          (e.priority >= 9 ||
              (e.dueAt != null &&
                  !e.dueAt!.isAfter(now) &&
                  _isSameLocalDay(e.dueAt, now)))),
      'smart.completed' => alive.where((e) => e.isCompleted),
      _ => alive.where((e) => e.listId == listId),
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
