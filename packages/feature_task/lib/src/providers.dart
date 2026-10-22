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
