import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../design/life_tokens.dart';

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
    final radius = BorderRadius.circular(LifeTokens.radiusCard);
    final padding = compact ? 8.0 : 10.0;
    final iconSize = compact ? 16.0 : 18.0;
    final countSize = compact ? 17.0 : 20.0;
    final titleSize = compact ? 12.0 : 13.0;
    return Material(
      key: ValueKey('smart_card_${list.id}'),
      color: Colors.transparent,
      borderRadius: radius,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LifeTokens.smartGradient(list.id),
          borderRadius: radius,
          border: selected
              ? Border.all(color: Colors.white.withValues(alpha: 0.92), width: 2)
              : null,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_icon(list.id), color: Colors.white, size: iconSize),
                    const Spacer(),
                    Text(
                      '${list.itemCount}',
                      style: TextStyle(
                        color: Colors.white,
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
                    color: Colors.white,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _icon(String id) {
    return switch (id) {
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
