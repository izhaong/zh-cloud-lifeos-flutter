import 'package:app_ui/app_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../design/reminder_tokens.dart';
import '../providers.dart';

/// 共享清单的只读内容区（flutter#600 路线 B）。
///
/// 为什么不走 `ListContentPane`：那条路径的条目来自 `itemsForListProvider`
/// （本地 Drift 流），而共享清单不进本地表——同步是按本人 owner 落库的。
/// 这里直连服务端读侧，**刻意不提供任何写入口**：别人的清单一旦被写回本地仓库，
/// 就会带着我的 outbox 记录推上去（#600 的硬判据 2）。
/// 因此「可编辑」角色在本视图里也只显示、不写；写侧要接，得单独开一条
/// 直连 REST 的写通道并明确不落 outbox，那是另一张卡的量级。
class SharedListPane extends ConsumerWidget {
  const SharedListPane({super.key, required this.list, this.leading});

  final TaskSharedList list;
  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(sharedListTasksProvider(list.listId));
    final items = itemsAsync.asData?.value ?? const <TaskSharedItem>[];
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(
        CupertinoColors.systemBackground,
        context,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  ?leading,
                  Expanded(
                    child: Text(
                      list.name.isEmpty ? '共享清单' : list.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // 「只读」徽标：#600 判据 3 的可见面——非所有者看不到任何写入口，
                  // 这里把口径写在脸上，而不是让用户对着一个不会响的按钮猜。
                  Container(
                    key: const ValueKey('shared_readonly_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ReminderTokens.systemBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(LifeRadius.lg),
                    ),
                    child: Text(
                      '只读 · ${taskShareRoleLabel(list.role)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            if (itemsAsync.isLoading && items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (itemsAsync.hasError)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '读不到这张共享清单',
                  style: TextStyle(
                    color: CupertinoDynamicColor.resolve(
                      ReminderTokens.labelSecondary,
                      context,
                    ),
                  ),
                ),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '没有提醒',
                  style: TextStyle(
                    color: CupertinoDynamicColor.resolve(
                      ReminderTokens.labelSecondary,
                      context,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => _SharedItemRow(item: items[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 只读行：状态是画出来的，不是点得动的。
class _SharedItemRow extends StatelessWidget {
  const _SharedItemRow({required this.item});

  final TaskSharedItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('shared_item_${item.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            item.completed
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.circle,
            size: 20,
            color: item.completed
                ? ReminderTokens.labelSecondary
                : ReminderTokens.systemBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                decoration: item.completed ? TextDecoration.lineThrough : null,
                color: CupertinoDynamicColor.resolve(
                  ReminderTokens.labelPrimary,
                  context,
                ),
              ),
            ),
          ),
          if (item.dueAt != null)
            Text(
              _dueLabel(item.dueAt!),
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }

  static String _dueLabel(DateTime d) =>
      '${d.month}/${d.day}';
}
