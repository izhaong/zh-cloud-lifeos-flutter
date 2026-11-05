import 'package:cupertino_ui/cupertino_ui.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../design/reminder_tokens.dart';

/// Apple Reminders 参考图同款智能列表卡：渐变色、白色图标/计数/标题。
///
/// 桌面侧栏与紧凑首页共用；高度由外层 Grid 决定。
class SmartListCard extends StatelessWidget {
  const SmartListCard({
    super.key,
    required this.list,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final ReminderList list;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ReminderTokens.radiusCard);
    final padding = compact ? 8.0 : 10.0;
    final iconSize = compact ? 16.0 : 18.0;
    final countSize = compact ? 17.0 : 20.0;
    final titleSize = compact ? 12.0 : 13.0;
    return CupertinoButton(
      key: ValueKey('smart_card_${list.id}'),
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      borderRadius: radius,
      pressedOpacity: 0.86,
      onPressed: onTap,
      child: Container(
        key: ValueKey('smart_card_surface_${list.id}'),
        decoration: BoxDecoration(
          gradient: list.isSmart
              ? ReminderTokens.smartGradient(list.id)
              // #588：置顶的自有清单也走这张卡，底色用它自己的列表色。
              : ReminderTokens.gradientFromColor(Color(list.colorArgb)),
          borderRadius: radius,
          border: selected
              ? Border.all(
                  color: CupertinoColors.white.withValues(alpha: 0.92),
                  width: 2,
                )
              : null,
        ),
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _icon(list),
                  color: CupertinoColors.white,
                  size: iconSize,
                ),
                const Spacer(),
                Text(
                  '${list.itemCount}',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: countSize,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              list.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(ReminderList list) {
    // #588：置顶的自有清单进卡片区时，Apple 的卡片图标是书签；
    // 采购清单仍用购物车（与「我的列表」行里的图标语义保持一致）。
    if (!list.isSmart) {
      return list.listType == ReminderListType.grocery
          ? CupertinoIcons.cart_fill
          : CupertinoIcons.bookmark_fill;
    }
    return switch (list.id) {
      'smart.today' => CupertinoIcons.today,
      'smart.scheduled' => CupertinoIcons.calendar,
      'smart.all' => CupertinoIcons.tray_full,
      'smart.flagged' => CupertinoIcons.flag_fill,
      'smart.urgent' => CupertinoIcons.exclamationmark_triangle_fill,
      'smart.completed' => CupertinoIcons.checkmark_alt_circle,
      'smart.assigned' => CupertinoIcons.person_crop_circle,
      'smart.trash' => CupertinoIcons.trash,
      _ => CupertinoIcons.list_bullet,
    };
  }
}
