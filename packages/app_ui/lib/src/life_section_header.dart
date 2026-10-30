import 'package:cupertino_ui/cupertino_ui.dart';

import 'design/life_colors.dart';

/// 分组/分区标题行（Epic #126 / A3 + B1）。
///
/// 替换此前散在四个文件里的私有实现：静态标题（日历侧栏/设置）与可折叠
/// 标题（任务侧栏/列表分区）合并为一套，视觉与键位保持不变：
/// 13px / w600 / [LifeColors.labelSecondary]。
///
/// - 传 [onToggle] 即为可折叠形态：右侧 chevron 随 [collapsed] 转向，整行可点；
/// - [count] 非空时在标题后显示「(N)」；
/// - [sectionKey] 供调用方保留既有定位键（如 `ValueKey('section_今天')`）。
class LifeSectionHeader extends StatelessWidget {
  const LifeSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.collapsed,
    this.onToggle,
    this.onAdd,
    this.sectionKey,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 4),
  });

  final String title;
  final int? count;
  final bool? collapsed;
  final VoidCallback? onToggle;
  final VoidCallback? onAdd;
  final Key? sectionKey;
  final EdgeInsetsGeometry padding;

  bool get _collapsible => onToggle != null;
  bool get _hasAdd => onAdd != null;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LifeColors.labelSecondary,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 13,
                color: LifeColors.labelSecondary,
              ),
            ),
          ],
          if (_hasAdd) ...[
            const Spacer(),
            CupertinoButton(
              key: const ValueKey('section_add_btn'),
              padding: const EdgeInsets.all(2),
              onPressed: onAdd,
              child: const Icon(CupertinoIcons.add, size: 16),
            ),
          ],
          if (_collapsible) ...[
            const Spacer(),
            Icon(
              (collapsed ?? false)
                  ? CupertinoIcons.chevron_down
                  : CupertinoIcons.chevron_up,
              size: 14,
              color: LifeColors.labelSecondary,
            ),
          ],
        ],
      ),
    );

    if (!_collapsible && !_hasAdd) {
      return KeyedSubtree(key: sectionKey, child: row);
    }
    return GestureDetector(
      key: sectionKey,
      behavior: HitTestBehavior.opaque,
      onTap: _collapsible ? onToggle : null,
      child: row,
    );
  }
}
