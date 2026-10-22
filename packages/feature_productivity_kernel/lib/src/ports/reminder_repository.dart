import '../models/reminder_item.dart';
import '../models/reminder_list.dart';

/// 提醒数据端口；首期内存实现，后续换 Drift。
abstract interface class ReminderRepository {
  Future<List<ReminderList>> watchLists();
  Future<List<ReminderItem>> watchItems({String? listId});
  Future<void> upsertItem(ReminderItem item);
  Future<void> toggleCompleted(String itemId);
}

/// 内存桩：便于壳层与 UI 冒烟。
final class InMemoryReminderRepository implements ReminderRepository {
  InMemoryReminderRepository() {
    _lists.addAll(const [
      ReminderList(id: 'smart.today', title: '今天', isSmart: true, itemCount: 2),
      ReminderList(id: 'smart.scheduled', title: '计划', isSmart: true, itemCount: 1),
      ReminderList(id: 'smart.all', title: '全部', isSmart: true, itemCount: 3),
      ReminderList(id: 'smart.flagged', title: '已旗标', isSmart: true, itemCount: 1),
      ReminderList(id: 'list.personal', title: '个人', colorArgb: 0xFF34C759, itemCount: 2),
      ReminderList(id: 'list.work', title: '工作', colorArgb: 0xFFFF9500, itemCount: 1),
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
  }

  final List<ReminderList> _lists = [];
  final List<ReminderItem> _items = [];

  @override
  Future<List<ReminderList>> watchLists() async =>
      List<ReminderList>.unmodifiable(_lists);

  @override
  Future<List<ReminderItem>> watchItems({String? listId}) async {
    final filtered = listId == null || listId.startsWith('smart.')
        ? _items
        : _items.where((e) => e.listId == listId);
    return List<ReminderItem>.unmodifiable(filtered);
  }

  @override
  Future<void> upsertItem(ReminderItem item) async {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i >= 0) {
      _items[i] = item;
    } else {
      _items.add(item);
    }
  }

  @override
  Future<void> toggleCompleted(String itemId) async {
    final i = _items.indexWhere((e) => e.id == itemId);
    if (i < 0) return;
    final cur = _items[i];
    _items[i] = cur.copyWith(isCompleted: !cur.isCompleted);
  }
}
