import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/reminder_tokens.dart';
import '../providers.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// 「设置」弹窗（图1 对齐）：默认列表 / 全天提醒时点 / 标记完成开关 /
/// 建议列表开关 / 还原默认。
///
/// TC-UI-120 持久半边（flutter#124 卡 4）：四档都写进 [TaskPreferenceRepository]，
/// 重开与冷启动读回同一行；「还原」= 写回契约默认（含默认列表清回未设置）。
///
/// #444：原「采购清单语言」行是硬编码 `Text('简体中文')`（无 `onTap`、不落库、
/// 无消费者），按「要么补消费者、要么不摆成可设置的样子」撤除。采购清单预设分区
/// 仍按 HT105086 降级口径固定中文，与服务端 `TodoListDO.GROCERY_PRESET_SECTIONS`
/// 保持同一套名字；要按语言出第二套模板得先解决与服务端常量的对齐，另单跟。
/// 默认列表用就地展开的候选区（不额外推一层路由）：少一套导航假设，
/// 测试与真机走的是同一条路径。
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

class _TaskSettingsSheet extends ConsumerStatefulWidget {
  const _TaskSettingsSheet({
    required this.scrollController,
    this.onOpenCloudLogin,
  });

  final ScrollController scrollController;
  final void Function(BuildContext sheetContext)? onOpenCloudLogin;

  @override
  ConsumerState<_TaskSettingsSheet> createState() =>
      _TaskSettingsSheetState();
}

class _TaskSettingsSheetState extends ConsumerState<_TaskSettingsSheet> {
  /// 写后回声：落库与流广播之间有一帧，先用本地值渲染，避免开关「点下去又弹回去」。
  TaskPreference? _local;
  bool _pickingDefaultList = false;

  TaskPreference get _pref =>
      _local ??
      ref.watch(taskPreferenceProvider).value ??
      TaskPreference.defaults;

  void _save(TaskPreference next) {
    setState(() => _local = next);
    ref.read(taskPreferenceRepositoryProvider).savePreference(next);
  }

  /// 自有列表（默认列表候选；智能列表不是用户数据，不能当默认列表）。
  List<ReminderList> get _ownLists =>
      (ref.watch(reminderListsProvider).value ?? const <ReminderList>[])
          .where((l) => !l.isSmart)
          .toList(growable: false);

  String get _defaultListLabel {
    final id = _pref.defaultListId;
    if (id == null) return '未设置';
    final hit = _ownLists.where((l) => l.id == id);
    return hit.isEmpty ? '未设置' : hit.first.title;
  }

  void _chooseDefaultList(String? id) {
    setState(() => _pickingDefaultList = false);
    _save(id == null
        ? _pref.copyWith(clearDefaultListId: true)
        : _pref.copyWith(defaultListId: id));
  }

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final p = _pref;
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
                  rowKey: 'settings_default_list',
                  onTap: () =>
                      setState(() => _pickingDefaultList = !_pickingDefaultList),
                  trailing: Text(
                    _defaultListLabel,
                    style: TextStyle(color: secondary),
                  ),
                ),
                if (_pickingDefaultList)
                  _optionRow(
                    key: 'default_list_none',
                    title: '无',
                    selected: p.defaultListId == null,
                    onTap: () => _chooseDefaultList(null),
                  ),
                if (_pickingDefaultList)
                  for (final l in _ownLists)
                    _optionRow(
                      key: 'default_list_${l.id}',
                      title: l.title,
                      selected: p.defaultListId == l.id,
                      onTap: () => _chooseDefaultList(l.id),
                    ),
                _switchRow(
                  icon: CupertinoIcons.clock,
                  label: '全天提醒时点',
                  rowKey: 'settings_all_day_notify',
                  value: p.allDayNotify,
                  onChanged: (v) => _save(p.copyWith(allDayNotify: v)),
                ),
                _switchRow(
                  icon: CupertinoIcons.checkmark_circle,
                  label: '完成时标记为已完成',
                  rowKey: 'settings_mark_complete',
                  value: p.markComplete,
                  onChanged: (v) => _save(p.copyWith(markComplete: v)),
                ),
                _switchRow(
                  icon: CupertinoIcons.sparkles,
                  label: '建议列表',
                  rowKey: 'settings_suggest_lists',
                  value: p.suggestLists,
                  onChanged: (v) => _save(p.copyWith(suggestLists: v)),
                ),
                // #446：全天提醒是否按逾期显示（消费者在 reminder_row._dueText）。
                _switchRow(
                  icon: CupertinoIcons.exclamationmark_circle,
                  label: '将全天提醒显示为逾期',
                  rowKey: 'settings_all_day_overdue',
                  value: p.allDayRemindersOverdue,
                  onChanged: (v) =>
                      _save(p.copyWith(allDayRemindersOverdue: v)),
                ),
                // #451：徽标数量是否含今天到期（消费者在 life_launcher 的 task_badge）。
                _switchRow(
                  icon: CupertinoIcons.bell,
                  label: '标记数量含今天到期',
                  rowKey: 'settings_badge_includes_today',
                  value: p.badgeIncludesTodayDue,
                  onChanged: (v) =>
                      _save(p.copyWith(badgeIncludesTodayDue: v)),
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
                  onTap: () {
                    // #256：按列表的「显示已完成」记忆也属于视图态，一并清零
                    ref.read(showCompletedByListProvider.notifier).reset();
                    _save(TaskPreference.defaults);
                  },
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
    required String rowKey,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    // 键挂在外壳上而不是 CupertinoListTile 上：直接把 key 给 tile，
    // find.descendant(of: byKey, matching: CupertinoSwitch) 会找不到
    // （trailing 不在那个被键住的子树里），断言就退化成「只能证明这行存在」。
    return KeyedSubtree(
      key: ValueKey<String>(rowKey),
      child: CupertinoListTile(
        leading: Icon(icon, color: ReminderTokens.systemBlue),
        title: Text(label),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String label,
    required String rowKey,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _row(
      icon: icon,
      label: label,
      rowKey: rowKey,
      trailing: CupertinoSwitch(value: value, onChanged: onChanged),
    );
  }

  /// 默认列表候选行（就地展开，不推一层路由）。
  Widget _optionRow({
    required String key,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return CupertinoListTile(
      key: ValueKey(key),
      padding: const EdgeInsets.only(left: 40),
      title: Text(title),
      trailing: selected
          ? const Icon(CupertinoIcons.checkmark,
              color: ReminderTokens.systemBlue)
          : null,
      onTap: onTap,
    );
  }
}
