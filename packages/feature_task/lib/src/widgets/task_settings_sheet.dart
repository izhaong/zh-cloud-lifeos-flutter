import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 「设置」弹窗（图1 对齐）：默认列表 / 全天提醒时点 / 标记完成开关 /
/// 建议列表开关 / 采购清单语言 / 还原默认（TC-UI-120 UI 真身——偏好持久
/// 接线属 P3，当前开关状态为会话级）。
Future<void> showTaskSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (sheetContext) => const _TaskSettingsSheet(),
  );
}

class _TaskSettingsSheet extends StatefulWidget {
  const _TaskSettingsSheet();

  @override
  State<_TaskSettingsSheet> createState() => _TaskSettingsSheetState();
}

class _TaskSettingsSheetState extends State<_TaskSettingsSheet> {
  bool _allDayNotify = true;
  bool _markComplete = false;
  bool _suggestLists = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                '设置',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            _row(
              icon: CupertinoIcons.list_bullet,
              label: '默认列表',
              trailing: const Text('提醒事项',
                  style: TextStyle(color: Color(0xFF8E8E93))),
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
              trailing: const Text('简体中文',
                  style: TextStyle(color: Color(0xFF8E8E93))),
            ),
            const Divider(height: 24),
            Center(
              child: CupertinoButton(
                key: const ValueKey('settings_reset'),
                padding: EdgeInsets.zero,
                onPressed: () => setState(() {
                  _allDayNotify = true;
                  _markComplete = false;
                  _suggestLists = true;
                }),
                child: const Text('还原默认设置',
                    style: TextStyle(fontSize: 15, color: Color(0xFF007AFF))),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '会员同步：登录后可用（真实同步在 cloud 侧）',
                style: TextStyle(fontSize: 12, color: Color(0xFFC7C7CC)),
              ),
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF007AFF)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          trailing,
        ],
      ),
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
