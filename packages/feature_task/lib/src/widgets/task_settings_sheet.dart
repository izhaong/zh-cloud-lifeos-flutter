import 'package:cupertino_ui/cupertino_ui.dart';

import '../design/reminder_tokens.dart';

/// 「设置」弹窗（图1 对齐）：默认列表 / 全天提醒时点 / 标记完成开关 /
/// 建议列表开关 / 采购清单语言 / 还原默认（TC-UI-120 UI 真身——偏好持久
/// 接线属 P3，当前开关状态为会话级）。
Future<void> showTaskSettingsSheet(
  BuildContext context, {
  void Function(BuildContext sheetContext)? onOpenCloudLogin,
}) {
  return Navigator.of(context).push(
    CupertinoSheetRoute<void>(
      scrollableBuilder: (sheetContext, scrollController) => _TaskSettingsSheet(
        scrollController: scrollController,
        onOpenCloudLogin: onOpenCloudLogin,
      ),
    ),
  );
}

class _TaskSettingsSheet extends StatefulWidget {
  const _TaskSettingsSheet({
    required this.scrollController,
    this.onOpenCloudLogin,
  });

  final ScrollController scrollController;
  final void Function(BuildContext sheetContext)? onOpenCloudLogin;

  @override
  State<_TaskSettingsSheet> createState() => _TaskSettingsSheetState();
}

class _TaskSettingsSheetState extends State<_TaskSettingsSheet> {
  bool _allDayNotify = true;
  bool _markComplete = false;
  bool _suggestLists = true;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          key: const ValueKey('settings_done'),
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
        middle: const Text('设置'),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          controller: widget.scrollController,
          children: [
            const SizedBox(height: 8),
            CupertinoListSection.insetGrouped(
              children: [
                _row(
                  icon: CupertinoIcons.list_bullet,
                  label: '默认列表',
                  trailing: Text(
                    '提醒事项',
                    style: TextStyle(color: secondary),
                  ),
                ),
                _switchRow(
                  icon: CupertinoIcons.clock,
                  label: '全天提醒时点',
                  value: _allDayNotify,
                  onChanged: (v) => setState(() => _allDayNotify = v),
                ),
                _switchRow(
                  icon: CupertinoIcons.checkmark_circle,
                  label: '完成时标记为已完成',
                  value: _markComplete,
                  onChanged: (v) => setState(() => _markComplete = v),
                ),
                _switchRow(
                  icon: CupertinoIcons.sparkles,
                  label: '建议列表',
                  value: _suggestLists,
                  onChanged: (v) => setState(() => _suggestLists = v),
                ),
                _row(
                  icon: CupertinoIcons.cart,
                  label: '采购清单语言',
                  trailing: Text(
                    '简体中文',
                    style: TextStyle(color: secondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  key: const ValueKey('settings_reset'),
                  leading: const Icon(
                    CupertinoIcons.arrow_counterclockwise,
                    color: ReminderTokens.systemBlue,
                  ),
                  title: const Text('还原默认设置'),
                  onTap: () => setState(() {
                    _allDayNotify = true;
                    _markComplete = false;
                    _suggestLists = true;
                  }),
                ),
                CupertinoListTile(
                  key: const ValueKey('settings_cloud_login'),
                  leading: const Icon(
                    CupertinoIcons.cloud,
                    color: ReminderTokens.systemBlue,
                  ),
                  title: Text(
                    widget.onOpenCloudLogin == null
                        ? '云同步：登录后可用'
                        : '开启云同步',
                  ),
                  onTap: widget.onOpenCloudLogin == null
                      ? null
                      : () => widget.onOpenCloudLogin!(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required Widget trailing,
  }) {
    return CupertinoListTile(
      leading: Icon(icon, color: ReminderTokens.systemBlue),
      title: Text(label),
      trailing: trailing,
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _row(
      icon: icon,
      label: label,
      trailing: CupertinoSwitch(value: value, onChanged: onChanged),
    );
  }
}
