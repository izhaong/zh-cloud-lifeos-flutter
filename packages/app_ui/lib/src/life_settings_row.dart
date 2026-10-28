import 'package:cupertino_ui/cupertino_ui.dart';

import 'design/life_colors.dart';

/// 设置/表单里的**分组列表行**（Epic #126 / B2）。
///
/// 收编此前三份逐字相近的私有实现：
/// `calendar_settings_sheet._Row`、`calendar_settings_sheet._SwitchRow`、
/// `event_form_fields._SwitchRow`。三者共同形态：
/// 上下 10 / 左右 16 内边距 + 0.5 发丝分隔线 + 标题 16 + 副标题 12（次要色）。
///
/// **不**包含 Inspector 那种「蓝色前置图标 + 15px + 无分隔线」的行——那是另一个
/// 视觉族（`reminder_detail_pane._Row`），强行合并会改观感，留给需要目视复核的卡。
class LifeSettingsRow extends StatelessWidget {
  const LifeSettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.divider = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 是否为最后一行/独立行时关掉分隔线。
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: divider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 0.5,
                    color: CupertinoColors.separator.resolveFrom(context),
                  ),
                ),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: LifeColors.labelSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: trailing!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 开关行：整行可点即切换（复选语义与 Apple 设置一致）。
class LifeSwitchRow extends StatelessWidget {
  const LifeSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.divider = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return LifeSettingsRow(
      title: title,
      subtitle: subtitle,
      divider: divider,
      onTap: () => onChanged(!value),
      trailing: CupertinoSwitch(value: value, onChanged: onChanged),
    );
  }
}
