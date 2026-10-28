import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:app_core/app_core.dart';

import '../design/reminder_tokens.dart';
import '../providers.dart';
import 'reminder_row.dart';

/// 「详细信息」编辑面板（Apple 提醒事项对齐：备注 / 日期与时间 / 重复 /
/// 标记(旗标) / 标签 / 优先级 / 子任务）。
///
/// 布局无关：紧凑端模态页、宽屏第三栏共用。
/// 字段编辑 = copyWith + upsertItem 全量回写；
/// 子任务直接读写仓库（parentId 挂本条目），随流自动刷新。
class ReminderDetailPane extends ConsumerStatefulWidget {
  const ReminderDetailPane({
    super.key,
    required this.item,
    required this.onSaved,
    this.onClose,
  });

  final ReminderItem item;
  final ValueChanged<ReminderItem> onSaved;
  final VoidCallback? onClose;

  @override
  ConsumerState<ReminderDetailPane> createState() => _ReminderDetailPaneState();
}

class _ReminderDetailPaneState extends ConsumerState<ReminderDetailPane> {
  late final TextEditingController _title = TextEditingController();
  late final TextEditingController _notes = TextEditingController();
  late final TextEditingController _tags = TextEditingController();
  late final TextEditingController _subtask = TextEditingController();
  late bool _isFlagged;
  late int _priority;
  late String? _recurrence;
  DateTime? _recurrenceUntil;
  DateTime? _dueAt;
  bool _showSubtaskDraft = false;

  /// 即改即存（#153）：文本字段输入后置脏，失焦/换行/关面板时兜底提交，
  /// 避免只点选择器不点「完成」导致编辑丢失。
  bool _dirty = false;
  bool _deleted = false;

  late final FocusNode _titleFocus = _blurOnUnfocus();
  late final FocusNode _notesFocus = _blurOnUnfocus();
  late final FocusNode _tagsFocus = _blurOnUnfocus();

  /// 失焦兜底提交（#153）：焦点离开字段时若有未落库编辑则回写。
  FocusNode _blurOnUnfocus() {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus) _commitIfDirty();
    });
    return node;
  }

  @override
  void initState() {
    super.initState();
    _bindControllers();
  }

  /// 换条目（同面板复用）时重置全部本地编辑态；
  /// 未提交的草稿编辑丢弃（对齐 Apple inspector 切行即显示新条目语义）。
  @override
  void didUpdateWidget(covariant ReminderDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _bindControllers();
    }
  }

  void _bindControllers() {
    _title.text = widget.item.title;
    _notes.text = widget.item.notes ?? '';
    _tags.text = widget.item.tags.join(', ');
    _subtask.clear();
    _isFlagged = widget.item.isFlagged;
    _priority = widget.item.priority;
    _recurrence = widget.item.recurrence;
    _recurrenceUntil = widget.item.recurrenceUntil;
    _dueAt = widget.item.dueAt;
    _showSubtaskDraft = false;
  }

  @override
  void dispose() {
    if (_dirty && !_deleted) _save();
    _title.dispose();
    _notes.dispose();
    _tags.dispose();
    _subtask.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    _tagsFocus.dispose();
    super.dispose();
  }

  ReminderRepository get _repo => ref.read(reminderRepositoryProvider);

  void _save() {
    final tagList = _tags.text
        .split(RegExp(r'[,，]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final updated = widget.item.copyWith(
      title: _title.text.trim().isEmpty ? widget.item.title : _title.text,
      notes: _notes.text.isEmpty ? ReminderItem.clear : _notes.text,
      isFlagged: _isFlagged,
      priority: _priority,
      dueAt: _dueAt ?? ReminderItem.clear,
      recurrence: _recurrence ?? ReminderItem.clear,
      // cursor T-04 R2：规则清空（永不）时结束日一并清——防旧结束日被静默沿用
      recurrenceUntil: _recurrence == null
          ? ReminderItem.clear
          : (_recurrenceUntil ?? ReminderItem.clear),
      tags: tagList,
    );
    _dirty = false;
    widget.onSaved(updated);
  }

  /// 失焦时兜底提交（#153）：有未落库编辑才回写，避免无谓 upsert。
  void _commitIfDirty() {
    if (!_dirty) return;
    _save();
  }

  Future<void> _delete() async {
    _deleted = true;
    await _repo.deleteItem(widget.item.id);
    if (!mounted) return;
    widget.onClose?.call();
  }

  Future<void> _submitSubtask() async {
    final title = _subtask.text.trim();
    if (title.isEmpty) return; // 空标题不落库
    await _repo.upsertItem(
      ReminderItem(
        id: newReminderId(),
        listId: widget.item.listId,
        title: title,
        parentId: widget.item.id,
      ),
    );
    _subtask.clear();
    setState(() => _showSubtaskDraft = false);
  }

  Future<void> _deleteSubtask(String id) => _repo.deleteItem(id);

  /// 当前所属列表标题（无（如智能视图选中）兜底空）。
  String? get _currentListTitle {
    final lists =
        ref.read(reminderListsProvider).asData?.value ?? const <ReminderList>[];
    for (final l in lists) {
      if (l.id == widget.item.listId) return l.title;
    }
    return null;
  }

  /// 移动到其他列表（TC-UI-119）：copyWith(listId) 全量回写；
  /// 分区随列表 ⇒ 一并清空（与 TC-API-118 服务端口径一致）。
  Future<void> _moveToOtherList() async {
    final lists =
        (ref.read(reminderListsProvider).asData?.value ??
                const <ReminderList>[])
            .where((l) => !l.isSmart && l.id != widget.item.listId)
            .toList(growable: false);
    if (lists.isEmpty) return;
    if (!mounted) return;
    final target = await showCupertinoDialog<ReminderList>(
      context: context,
      builder: (context) => LifeAlertDialog(
        key: const ValueKey('move_to_list_dialog'),
        title: const Text('移动到列表'),
        actions: [
          for (final l in lists)
            LifeDialogAction(
              key: ValueKey('move_target_${l.id}'),
              onPressed: () => Navigator.of(context).pop(l),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(l.colorArgb),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(l.title),
                ],
              ),
            ),
        ],
      ),
    );
    if (target == null) return;
    await _repo.moveItem(widget.item.id, target.id);
  }

  /// T-04：结束日期选择（回调式弹层：确认/取消按钮；空=永不）。
  Future<void> _pickRecurrenceUntil() async {
    var picked = _recurrenceUntil ?? DateTime.now();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => Container(
        key: const ValueKey('recurrence_until_sheet'),
        height: 340,
        color: const Color(0xFFF2F2F7),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    key: const ValueKey('recurrence_until_cancel'),
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消'),
                  ),
                  CupertinoButton(
                    key: const ValueKey('recurrence_until_confirm'),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('好'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                key: const ValueKey('recurrence_until_picker'),
                initialDateTime: picked,
                mode: CupertinoDatePickerMode.date,
                use24hFormat: true,
                onDateTimeChanged: (d) => picked = d,
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      setState(() => _recurrenceUntil = picked);
      _save();
    }
  }

  String _dueLabel() {
    final d = _dueAt;
    if (d == null) return '无';
    final date = _fmtDate(d);
    if (d.hour == 0 && d.minute == 0) return date;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }

  Future<void> _pickDueAt() async {
    var picked = _dueAt ?? DateTime.now().add(const Duration(hours: 1));
    picked = DateTime(
      picked.year,
      picked.month,
      picked.day,
      picked.hour,
      picked.minute - picked.minute % 5,
    );
    var allDay = _dueAt != null && picked.hour == 0 && picked.minute == 0;
    final result = await showCupertinoModalPopup<Object?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            key: const ValueKey('due_at_editor'),
            height: 380,
            color: CupertinoDynamicColor.resolve(ReminderTokens.windowBg, context),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        key: const ValueKey('due_at_cancel'),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('取消'),
                      ),
                      CupertinoButton(
                        key: const ValueKey('due_at_clear'),
                        onPressed: () =>
                            Navigator.of(ctx).pop(ReminderItem.clear),
                        child: const Text(
                          '清除',
                          style: TextStyle(color: ReminderTokens.systemRed),
                        ),
                      ),
                      CupertinoButton(
                        key: const ValueKey('due_at_confirm'),
                        onPressed: () => Navigator.of(ctx).pop(picked),
                        child: const Text('好'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text('全天', style: TextStyle(fontSize: 15)),
                      const Spacer(),
                      CupertinoSwitch(
                        key: const ValueKey('due_at_all_day'),
                        value: allDay,
                        onChanged: (v) => setSheetState(() {
                          allDay = v;
                          picked = v
                              ? DateTime(picked.year, picked.month, picked.day)
                              : DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  9,
                                  0,
                                );
                        }),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    key: ValueKey('due_at_picker_$allDay'),
                    initialDateTime: picked,
                    mode: CupertinoDatePickerMode.dateAndTime,
                    minuteInterval: 5,
                    use24hFormat: true,
                    onDateTimeChanged: (d) {
                      picked = allDay ? DateTime(d.year, d.month, d.day) : d;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result == null) return;
    if (identical(result, ReminderItem.clear)) {
      setState(() => _dueAt = null);
      _save();
      return;
    }
    if (result is DateTime) {
      setState(() => _dueAt = result);
      _save();
    }
  }

  static const _recurrenceLabels = <String, String>{
    'daily': '每天',
    'weekly': '每周',
    'weekdays': '工作日',
    'monthly': '每月',
    'yearly': '每年',
  };

  String get _recurrenceLabel =>
      _recurrence == null ? '永不' : _recurrenceLabels[_recurrence]!;

  /// 重复规则选择（ActionSheet；当前规则高亮）。
  /// 「永不」以空串出参（pop(null) 与取消同形，无法区分）。
  Future<void> _pickRecurrence() async {
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => LifeActionSheet(
        title: const Text('重复'),
        actions: [
          for (final entry in {null: '永不', ..._recurrenceLabels}.entries)
            LifeActionSheetAction(
              key: ValueKey('recurrence_${entry.key ?? 'none'}'),
              isDefaultAction: entry.key == _recurrence,
              onPressed: () => Navigator.of(ctx).pop(entry.key ?? ''),
              child: Text(entry.value),
            ),
        ],
        cancelButton: LifeActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _recurrence = selected.isEmpty ? null : selected;
      if (selected.isEmpty) _recurrenceUntil = null;
    });
    _save();
  }

  static const _priorityLabels = <int, String>{
    0: '无 —',
    1: '低 !',
    5: '中 !!',
    9: '高 !!!',
  };

  /// 优先级选择（ActionSheet；当前值高亮）。
  Future<void> _pickPriority() async {
    final selected = await showCupertinoModalPopup<int>(
      context: context,
      builder: (ctx) => LifeActionSheet(
        title: const Text('优先级'),
        actions: [
          for (final entry in _priorityLabels.entries)
            LifeActionSheetAction(
              key: ValueKey('priority_${entry.key}'),
              isDefaultAction: entry.key == _priority,
              onPressed: () => Navigator.of(ctx).pop(entry.key),
              child: Text(entry.value),
            ),
        ],
        cancelButton: LifeActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _priority = selected);
    _save();
  }

  Widget _groupedRows(List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(ReminderTokens.radiusCard + 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const _Hairline(indent: 48),
            rows[i],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtasksAsync = ref.watch(itemsForListProvider(widget.item.listId));
    final subtasks = subtasksAsync.maybeWhen(
      data: (items) => items
          .where((e) => e.parentId == widget.item.id)
          .toList(growable: false),
      orElse: () => const <ReminderItem>[],
    );

    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(ReminderTokens.windowBg, context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoDynamicColor.resolve(ReminderTokens.windowBg, context),
        automaticallyImplyLeading: false,
        middle: const Text(
          '详细信息',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: widget.onClose != null
            ? CupertinoButton(
                key: const ValueKey('detail_close'),
                padding: EdgeInsets.zero,
                onPressed: widget.onClose,
                child: const Icon(CupertinoIcons.xmark, size: 20),
              )
            : null,
        trailing: CupertinoButton(
          key: const ValueKey('detail_save'),
          onPressed: _save,
          child: const Text('完成'),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // 标题 + 备注区（iOS 卡片样式）
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                CupertinoTextField(
                  key: const ValueKey('detail_title'),
                  controller: _title,
                  focusNode: _titleFocus,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                  placeholder: '标题',
                  decoration: const BoxDecoration(),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onChanged: (_) => _dirty = true,
                  onSubmitted: (_) => _save(),
                ),
                const _Hairline(),
                CupertinoTextField(
                  key: const ValueKey('detail_notes'),
                  controller: _notes,
                  focusNode: _notesFocus,
                  maxLines: 3,
                  placeholder: '备注',
                  decoration: const BoxDecoration(),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onChanged: (_) => _dirty = true,
                  onSubmitted: (_) => _save(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _groupedRows([
            _Row(
              key: const ValueKey('due_at_row'),
              icon: CupertinoIcons.calendar,
              label: '日期与时间',
              onTap: _pickDueAt,
              trailing: Text(_dueLabel()),
            ),
            _Row(
              icon: CupertinoIcons.arrow_2_circlepath,
              label: '重复',
              trailing: CupertinoButton(
                key: const ValueKey('recurrence_menu'),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: _pickRecurrence,
                child: Text(
                  _recurrenceLabel,
                  style: const TextStyle(color: Color(0xFF8E8E93)),
                ),
              ),
            ),
            if (_recurrence != null)
              _Row(
                key: const ValueKey('recurrence_until_row'),
                icon: CupertinoIcons.calendar_badge_minus,
                label: '结束日期',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _recurrenceUntil == null
                          ? '永不'
                          : '${_recurrenceUntil!.year}-'
                                '${_recurrenceUntil!.month.toString().padLeft(2, '0')}-'
                                '${_recurrenceUntil!.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Color(0xFF8E8E93)),
                    ),
                    CupertinoButton(
                      key: const ValueKey('recurrence_until_clear'),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      child: const Icon(
                        CupertinoIcons.clear,
                        size: 14,
                        color: Color(0xFFC7C7CC),
                      ),
                      onPressed: () {
                        setState(() => _recurrenceUntil = null);
                        _save();
                      },
                    ),
                  ],
                ),
                onTap: _pickRecurrenceUntil,
              ),
            _Row(
              icon: CupertinoIcons.flag_fill,
              label: '标记',
              trailing: CupertinoSwitch(
                value: _isFlagged,
                onChanged: (v) {
                  setState(() => _isFlagged = v);
                  _save();
                },
              ),
            ),
            _Row(
              icon: CupertinoIcons.tag,
              label: '标签',
              trailing: SizedBox(
                width: 160,
                child: CupertinoTextField(
                  key: const ValueKey('detail_tags'),
                  controller: _tags,
                  focusNode: _tagsFocus,
                  textAlign: TextAlign.right,
                  placeholder: '如：工作, 设计',
                  decoration: const BoxDecoration(),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  onChanged: (_) => _dirty = true,
                  onSubmitted: (_) => _save(),
                ),
              ),
            ),
            _Row(
              icon: CupertinoIcons.exclamationmark_circle,
              label: '优先级',
              trailing: CupertinoButton(
                key: const ValueKey('priority_menu'),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: _pickPriority,
                child: Text(
                  _priority == 0
                      ? '无'
                      : switch (_priority) {
                          >= 9 => '高 !!!',
                          >= 5 => '中 !!',
                          _ => '低 !',
                        },
                  style: const TextStyle(color: Color(0xFF8E8E93)),
                ),
              ),
            ),
            // 移动到其他列表（TC-UI-119 / TC-API-118 同语义：跨列表移动清分区）
            _Row(
              icon: CupertinoIcons.folder,
              label: '列表',
              trailing: CupertinoButton(
                key: const ValueKey('move_to_list'),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: _moveToOtherList,
                child: Text(
                  _currentListTitle ?? '移动到…',
                  style: const TextStyle(
                    color: Color(0xFF007AFF),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // 子任务：真实列表（勾选/删除随流刷新）+ 新建草稿行
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final sub in subtasks)
                  Dismissible(
                    key: ValueKey('subtask_${sub.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: const Color(0xFFFF3B30),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        CupertinoIcons.delete,
                        color: CupertinoColors.white,
                      ),
                    ),
                    onDismissed: (_) => _deleteSubtask(sub.id),
                    child: ReminderRow(
                      item: sub,
                      dense: true,
                      onToggleCompleted: () => completeReminder(ref, sub),
                    ),
                  ),
                if (_showSubtaskDraft)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.circle,
                          size: 18,
                          color: Color(0xFFC7C7CC),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoTextField(
                            key: const ValueKey('detail_subtask'),
                            controller: _subtask,
                            autofocus: true,
                            placeholder: '子任务',
                            onSubmitted: (_) => _submitSubtask(),
                            decoration: const BoxDecoration(),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                CupertinoButton(
                  onPressed: () => setState(() => _showSubtaskDraft = true),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        CupertinoIcons.add,
                        size: 20,
                        color: Color(0xFF007AFF),
                      ),
                      SizedBox(width: 8),
                      Text('添加子任务', style: TextStyle(color: Color(0xFF007AFF))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Center(
              child: CupertinoButton(
                key: const ValueKey('detail_delete'),
                onPressed: _delete,
                child: const Text(
                  '删除提醒',
                  style: TextStyle(color: ReminderTokens.systemRed),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }
}

/// 0.5px 分隔线（iOS 发丝线）。
class _Hairline extends StatelessWidget {
  const _Hairline({this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: EdgeInsets.only(left: indent),
      color: CupertinoDynamicColor.resolve(ReminderTokens.separator, context),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget trailing;

  /// T-04：行可点（结束日期选择）。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: ReminderTokens.systemBlue, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(width: 8),
            // 测试环境 Ahem 字体下固定宽（如时间文本）会超出可用宽度，允许收缩
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: trailing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
