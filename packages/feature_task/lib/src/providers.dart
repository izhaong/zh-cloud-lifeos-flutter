import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// 仓库契约 Provider：feature_task 内定义与消费，组合根（life_launcher）注入实现。
///
/// 测试中用 `ProviderScope(overrides: [...])` 注入 [InMemoryReminderRepository]；
/// 正式组合根先完成 Drift 开库，再 override 注入。
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  throw UnimplementedError(
    'reminderRepositoryProvider 未注入：请在组合根 ProviderScope.overrides '
    '中 overrideWith 提供 ReminderRepository 实现。',
  );
}, name: 'reminderRepositoryProvider');

/// 全部列表（智能 + 我的）。
final reminderListsProvider = StreamProvider<List<ReminderList>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchLists();
});

/// 条目流家族：`ref.watch(itemsForListProvider(listId))`；
/// 智能列表（`smart.` 前缀）由仓库按语义过滤。
final itemsForListProvider =
    StreamProvider.family<List<ReminderItem>, String?>((ref, listId) {
  return ref.watch(reminderRepositoryProvider).watchItems(listId: listId);
});

/// 全局搜索词（macOS 工具栏搜索 / ⌘F 聚焦；空串 = 不过滤）。
///
/// Riverpod 3 无 StateProvider，用最小 Notifier 承载可变搜索态。
final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

/// Pad/客户端提醒侧栏显隐（线框：隐藏后主区铺满，可再显示）。
final sidebarVisibleProvider =
    NotifierProvider<SidebarVisibleNotifier, bool>(SidebarVisibleNotifier.new);

class SidebarVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;

  void toggle() => state = !state;
}

/// 过滤后的条目流：在仓库语义过滤之上叠加本地文本匹配
/// （标题 / 备注 / 标签，大小写不敏感）+ 「显示已完成」视图偏好
/// （TC-UI-108：默认隐藏已完成；`smart.completed` 完成卡恒显示）。
final filteredItemsForListProvider =
    StreamProvider.family<List<ReminderItem>, String?>((ref, listId) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final showCompleted =
      ref.watch(showCompletedProvider) || listId == 'smart.completed';
  return ref
      .watch(reminderRepositoryProvider)
      .watchItems(listId: listId)
      .map((items) {
    var out = items;
    if (!showCompleted) {
      // 隐藏已完成顶层条目；子任务仍随父行渲染（完成态由行自身呈现）
      out = out
          .where((e) => !e.isCompleted || e.parentId != null)
          .toList(growable: false);
    }
    if (query.isEmpty) {
      return List<ReminderItem>.unmodifiable(out);
    }
    return List<ReminderItem>.unmodifiable(out
        .where((e) =>
            e.title.toLowerCase().contains(query) ||
            (e.notes ?? '').toLowerCase().contains(query) ||
            e.tags.any((t) => t.toLowerCase().contains(query)))
        .toList(growable: false));
  });
});

/// 「显示已完成」列表内开关（线框图2 工具行「显示」；TC-UI-108）。
final showCompletedProvider =
    NotifierProvider<ShowCompletedNotifier, bool>(ShowCompletedNotifier.new);

class ShowCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;

  void toggle() => state = !state;
}

/// 列表内排序模式（线框图2 工具行「排序」；TC-UI-111。
/// manual = 仓库排序契约 `sortOrder asc, id asc`）。
enum ListSortMode { manual, dueDate, title, priority }

final listSortModeProvider =
    NotifierProvider<ListSortModeNotifier, ListSortMode>(
        ListSortModeNotifier.new);

class ListSortModeNotifier extends Notifier<ListSortMode> {
  @override
  ListSortMode build() => ListSortMode.manual;

  void set(ListSortMode mode) => state = mode;
}
