// 任务徽标计数（#447）。
//
// 由来：`shellBadgeCountsProvider` 的默认实现返回 `const {}`，而**组合根从未 override**，
// 只有测试注入过 `{'task': 3}` 之类的假值——也就是说生产环境里任务页从来没有徽标数字。
// 「标记数量含今天到期」这类设置项因此无从谈起：先把数字做出来。
//
// 口径（Apple 提醒事项的「标记数量」）：**未完成**且属于「今天」的提醒条数，按 id 去重。
// 其中「今天」= 今天到期（含已过期的今天之前？不含——过期条目另有「逾期」概念，
// 不计入今天的徽标，否则徽标会随着拖延越积越大，与 Apple 的口径不同）。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart'
    show reminderRepositoryProvider, taskPreferenceProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 纯函数：算任务徽标数字。
///
/// [includeTodayDue] 对应母卡 #419 里那一项设置；本卡先固定为 true（= 只数今天到期），
/// 设置项（需要 drift 列迁移）另开卡再做。
int taskBadgeCount(
  List<ReminderItem> items, {
  required DateTime now,
  bool includeTodayDue = true,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final seen = <String>{};
  var count = 0;
  for (final item in items) {
    if (item.isCompleted || item.deletedAt != null) continue;
    if (item.parentId != null) continue; // 子任务不单独计数（与侧栏口径一致）
    final due = item.dueAt;
    if (due == null) continue;
    final dueDay = DateTime(due.year, due.month, due.day);
    final isToday = dueDay == today;
    final isTodayDue = includeTodayDue && isToday;
    // 过期（早于今天）不计入徽标：Apple 的标记数量语义是「今天要做的事」
    if (!isTodayDue) continue;
    if (seen.add(item.id)) count++;
  }
  return count;
}

/// 徽标数字的 Provider（组合根注入派生）。
///
/// `feature_task` 不 import 壳，壳也不该 import feature_task 的页面树；这里只依赖
/// kernel 的仓储契约（`ReminderRepository.watchItems`），符合壳的分层约束。
final taskBadgeCountsProvider = Provider<Map<String, int>>((ref) {
  final repository = ref.watch(reminderRepositoryProvider);
  final items = ref.watch(reminderItemsForBadgeProvider).value ??
      const <ReminderItem>[];
  // repository 只是为了确保未注入时能显式失败（与各 provider 的既有口径一致）
  repository.hashCode;
  // #451：设置项决定「今天到期」是否计入（默认 true，与 #447 初始口径一致）。
  final includeToday = ref.watch(taskPreferenceProvider).value
          ?.badgeIncludesTodayDue ??
      true;
  return {
    'task': taskBadgeCount(
      items,
      now: DateTime.now(),
      includeTodayDue: includeToday,
    ),
  };
});

/// 未完成提醒的流（徽标专用；不区分列表）。
final reminderItemsForBadgeProvider = StreamProvider<List<ReminderItem>>((ref) {
  final repository = ref.watch(reminderRepositoryProvider);
  return repository.watchItems();
});
