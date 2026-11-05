import 'package:app_core/app_core.dart';
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
  // #490：Apple 设置是独立窗口，主窗口仍可见。
  // CupertinoSheetRoute 是全屏抽屉，盖住主窗口；改用 CupertinoPageRoute
  // 非模态推入，主窗口继续可见。
  return Navigator.of(context).push(
    CupertinoPageRoute<void>(
      fullscreenDialog: false,
      builder: (sheetContext) => _TaskSettingsSheet(
        scrollController: ScrollController(),
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
  ConsumerState<_TaskSettingsSheet> createState() => _TaskSettingsSheetState();
}

class _TaskSettingsSheetState extends ConsumerState<_TaskSettingsSheet> {
  /// 写后回声：落库与流广播之间有一帧，先用本地值渲染，避免开关「点下去又弹回去」。
  TaskPreference? _local;

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

  void _reset() {
    // #256：按列表的「显示已完成」记忆也属于视图态，一并清零
    ref.read(showCompletedByListProvider.notifier).reset();
    _save(TaskPreference.defaults);
  }

  @override
  Widget build(BuildContext context) {
    // #595（口径 1）：同步状态只在设置面板里可见——主界面保持 #592 量到的「静默」。
    // TaskSettingsView 本体不碰 Riverpod（macOS 独立窗口共用它），故由这里算好传入。
    final cloudStatusLabel = ref.watch(syncStatusProvider).value?.settingsLabel;
    return TaskSettingsView(
      preference: _pref,
      ownLists: _ownLists,
      cloudStatusLabel: cloudStatusLabel,
      scrollController: widget.scrollController,
      onChanged: _save,
      onReset: _reset,
      onDone: () => Navigator.of(context).pop(),
      onOpenCloudLogin: widget.onOpenCloudLogin == null
          ? null
          : () => widget.onOpenCloudLogin!(context),
    );
  }
}

/// 设置面板本体（#577）：不依赖 Riverpod，偏好与列表由调用方注入。
///
/// 应用内页面与 macOS 独立辅助窗口共用这一份 UI——两处若各写一套，
/// 键位/文案/默认列表展开逻辑会漂移。
class TaskSettingsView extends StatefulWidget {
  const TaskSettingsView({
    super.key,
    required this.preference,
    required this.ownLists,
    required this.onChanged,
    required this.onReset,
    required this.onDone,
    this.onOpenCloudLogin,
    this.scrollController,
    this.cloudStatusLabel,
  });

  final TaskPreference preference;

  /// 自有列表（已滤掉智能列表）。
  final List<ReminderList> ownLists;

  final ValueChanged<TaskPreference> onChanged;
  final VoidCallback onReset;
  final VoidCallback onDone;
  final VoidCallback? onOpenCloudLogin;
  final ScrollController? scrollController;

  /// #595：「待推 N 条 · 上次同步 HH:mm」；null = 未登录或状态未知，不摆副标题。
  final String? cloudStatusLabel;

  @override
  State<TaskSettingsView> createState() => _TaskSettingsViewState();
}

class _TaskSettingsViewState extends State<TaskSettingsView> {
  bool _pickingDefaultList = false;

  TaskPreference get _pref => widget.preference;

  List<ReminderList> get _ownLists => widget.ownLists;

  String get _defaultListLabel {
    final id = _pref.defaultListId;
    if (id == null) return '未设置';
    final hit = _ownLists.where((l) => l.id == id);
    return hit.isEmpty ? '未设置' : hit.first.title;
  }

  void _chooseDefaultList(String? id) {
    setState(() => _pickingDefaultList = false);
    widget.onChanged(
      id == null
          ? _pref.copyWith(clearDefaultListId: true)
          : _pref.copyWith(defaultListId: id),
    );
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
          onPressed: widget.onDone,
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
                  onTap: () => setState(
                    () => _pickingDefaultList = !_pickingDefaultList,
                  ),
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
                  onChanged: (v) =>
                      widget.onChanged(p.copyWith(allDayNotify: v)),
                ),
                _switchRow(
                  icon: CupertinoIcons.checkmark_circle,
                  label: '完成时标记为已完成',
                  rowKey: 'settings_mark_complete',
                  value: p.markComplete,
                  onChanged: (v) =>
                      widget.onChanged(p.copyWith(markComplete: v)),
                ),
                _switchRow(
                  icon: CupertinoIcons.sparkles,
                  label: '建议列表',
                  rowKey: 'settings_suggest_lists',
                  value: p.suggestLists,
                  onChanged: (v) =>
                      widget.onChanged(p.copyWith(suggestLists: v)),
                ),
                // #448：手动设定时区（消费者是 kernel 的 `effectiveNow`，
                // 组合根把它接到仓储的 nowProvider + clockProvider）。
                _row(
                  icon: CupertinoIcons.globe,
                  label: '时区',
                  rowKey: 'settings_manual_time_zone',
                  onTap: () => _pickTimeZone(p),
                  trailing: Text(
                    p.manualTimeZone ?? '跟随系统',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                // #445：「今天」汇总通知时点（消费者在 life_launcher 的通知调度器）。
                _row(
                  icon: CupertinoIcons.time,
                  label: '「今天」通知时点',
                  rowKey: 'settings_today_notify_time',
                  onTap: () => _pickTodayNotifyTime(p),
                  trailing: Text(
                    p.todayNotifyTime,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                // #446：全天提醒是否按逾期显示（消费者在 reminder_row._dueText）。
                _switchRow(
                  icon: CupertinoIcons.exclamationmark_circle,
                  label: '将全天提醒显示为逾期',
                  rowKey: 'settings_all_day_overdue',
                  value: p.allDayRemindersOverdue,
                  onChanged: (v) =>
                      widget.onChanged(p.copyWith(allDayRemindersOverdue: v)),
                ),
                // #451：徽标数量是否含今天到期（消费者在 life_launcher 的 task_badge）。
                _switchRow(
                  icon: CupertinoIcons.bell,
                  label: '标记数量含今天到期',
                  rowKey: 'settings_badge_includes_today',
                  value: p.badgeIncludesTodayDue,
                  onChanged: (v) =>
                      widget.onChanged(p.copyWith(badgeIncludesTodayDue: v)),
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
                  onTap: widget.onReset,
                ),
                CupertinoListTile(
                  key: const ValueKey('settings_cloud_login'),
                  leading: const Icon(
                    CupertinoIcons.cloud,
                    color: ReminderTokens.systemBlue,
                  ),
                  title: Text(
                    widget.onOpenCloudLogin == null ? '云同步：登录后可用' : '开启云同步',
                  ),
                  subtitle: widget.cloudStatusLabel == null
                      ? null
                      : Text(
                          widget.cloudStatusLabel!,
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                  onTap: widget.onOpenCloudLogin,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// 常用时区（IANA）。不列全库：Apple 也是一小组常用项 + 「跟随系统」。
  static const _timeZones = <(String?, String)>[
    (null, '跟随系统'),
    ('Asia/Shanghai', '中国标准时间'),
    ('Asia/Tokyo', '日本标准时间'),
    ('Asia/Singapore', '新加坡时间'),
    ('Europe/London', '伦敦'),
    ('Europe/Berlin', '中欧时间'),
    ('America/New_York', '纽约'),
    ('America/Los_Angeles', '洛杉矶'),
    ('Australia/Sydney', '悉尼'),
  ];

  /// 选时区（#448）。
  Future<void> _pickTimeZone(TaskPreference current) async {
    var index = _timeZones.indexWhere((e) => e.$1 == current.manualTimeZone);
    if (index < 0) index = 0;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (popupContext) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(popupContext),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  key: const Key('time_zone_cancel'),
                  onPressed: () => Navigator.of(popupContext).pop(false),
                  child: const Text('取消'),
                ),
                CupertinoButton(
                  key: const Key('time_zone_done'),
                  onPressed: () => Navigator.of(popupContext).pop(true),
                  child: const Text('完成'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                key: const Key('time_zone_picker'),
                itemExtent: 36,
                scrollController: FixedExtentScrollController(
                  initialItem: index,
                ),
                onSelectedItemChanged: (i) => index = i,
                children: [
                  for (final (_, label) in _timeZones)
                    Center(child: Text(label)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final zone = _timeZones[index].$1;
    widget.onChanged(
      zone == null
          ? current.copyWith(clearManualTimeZone: true)
          : current.copyWith(manualTimeZone: zone),
    );
  }

  /// 选「今天」汇总通知时点（#445）。
  ///
  /// 用 CupertinoDatePicker 的 time 模式：Apple 也是滚轮选时间，不做自由文本输入
  /// （自由文本会造出 `25:99` 这种值，虽然解析层能兜回 09:00，但没必要让用户踩）。
  Future<void> _pickTodayNotifyTime(TaskPreference current) async {
    final (hour, minute) = current.todayNotifyHourMinute;
    var picked = DateTime(2026, 1, 1, hour, minute);
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (popupContext) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(popupContext),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  key: const Key('today_notify_cancel'),
                  onPressed: () => Navigator.of(popupContext).pop(false),
                  child: const Text('取消'),
                ),
                CupertinoButton(
                  key: const Key('today_notify_done'),
                  onPressed: () => Navigator.of(popupContext).pop(true),
                  child: const Text('完成'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                key: const Key('today_notify_picker'),
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: picked,
                onDateTimeChanged: (value) => picked = value,
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    widget.onChanged(current.copyWith(todayNotifyTime: text));
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
          ? const Icon(
              CupertinoIcons.checkmark,
              color: ReminderTokens.systemBlue,
            )
          : null,
      onTap: onTap,
    );
  }
}
