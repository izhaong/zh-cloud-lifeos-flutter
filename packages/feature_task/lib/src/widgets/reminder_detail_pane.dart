import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

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
  ConsumerState<ReminderDetailPane> createState() =>
      _ReminderDetailPaneState();
}

class _ReminderDetailPaneState extends ConsumerState<ReminderDetailPane> {
  late final TextEditingController _title = TextEditingController();
  late final TextEditingController _notes = TextEditingController();
  late final TextEditingController _tags = TextEditingController();
  late final TextEditingController _subtask = TextEditingController();
  late bool _isFlagged;
  late int _priority;
  late String? _recurrence;
  bool _showSubtaskDraft = false;

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
    _showSubtaskDraft = false;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _tags.dispose();
    _subtask.dispose();
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
      recurrence: _recurrence ?? ReminderItem.clear,
      tags: tagList,
    );
    widget.onSaved(updated);
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
    final lists = ref.read(reminderListsProvider).asData?.value ??
        const <ReminderList>[];
    for (final l in lists) {
      if (l.id == widget.item.listId) return l.title;
    }
    return null;
  }

  /// 移动到其他列表（TC-UI-119）：copyWith(listId) 全量回写；
  /// 分区随列表 ⇒ 一并清空（与 TC-API-118 服务端口径一致）。
  Future<void> _moveToOtherList() async {
    final lists = (ref.read(reminderListsProvider).asData?.value ??
            const <ReminderList>[])
        .where((l) => !l.isSmart && l.id != widget.item.listId)
        .toList(growable: false);
    if (lists.isEmpty) return;
    final target = await showDialog<ReminderList>(
      context: context,
      builder: (context) => SimpleDialog(
        key: const ValueKey('move_to_list_dialog'),
        title: const Text('移动到列表'),
        children: [
          for (final l in lists)
            SimpleDialogOption(
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

  @override
  Widget build(BuildContext context) {
    final subtasksAsync =
        ref.watch(itemsForListProvider(widget.item.listId));
    final subtasks = subtasksAsync.maybeWhen(
      data: (items) =>
          items.where((e) => e.parentId == widget.item.id).toList(
                growable: false,
              ),
      orElse: () => const <ReminderItem>[],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('详细信息'),
        leading: widget.onClose != null
            ? CloseButton(onPressed: widget.onClose)
            : null,
        actions: [
          TextButton(onPressed: _save, child: const Text('完成')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // 标题 + 备注区（iOS 卡片样式）
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '标题',
                    ),
                  ),
                  const Divider(height: 1),
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '备注',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 日期与时间（展示；编辑入口 Phase 4 完整日历选择）
          _Row(
            icon: CupertinoIcons.calendar,
            label: '日期与时间',
            trailing: Text(widget.item.dueAt == null
                ? '无'
                : _fmtDate(widget.item.dueAt!)),
          ),
          _Row(
            icon: CupertinoIcons.arrow_2_circlepath,
            label: '重复',
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _recurrence,
                items: const [
                  DropdownMenuItem(value: null, child: Text('永不')),
                  DropdownMenuItem(value: 'daily', child: Text('每天')),
                  DropdownMenuItem(value: 'weekly', child: Text('每周')),
                  DropdownMenuItem(value: 'weekdays', child: Text('工作日')),
                  DropdownMenuItem(value: 'monthly', child: Text('每月')),
                  DropdownMenuItem(value: 'yearly', child: Text('每年')),
                ],
                onChanged: (v) => setState(() => _recurrence = v),
              ),
            ),
          ),
          _Row(
            icon: CupertinoIcons.flag_fill,
            label: '标记',
            trailing: CupertinoSwitch(
              value: _isFlagged,
              onChanged: (v) => setState(() => _isFlagged = v),
            ),
          ),
          _Row(
            icon: CupertinoIcons.tag,
            label: '标签',
            trailing: SizedBox(
              width: 160,
              child: TextField(
                controller: _tags,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '如：工作, 设计',
                ),
              ),
            ),
          ),
          _Row(
            icon: CupertinoIcons.exclamationmark_circle,
            label: '优先级',
            trailing: PopupMenuButton<int>(
              initialValue: _priority,
              onSelected: (v) => setState(() => _priority = v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0, child: Text('无 —')),
                PopupMenuItem(value: 1, child: Text('低 !')),
                PopupMenuItem(value: 5, child: Text('中 !!')),
                PopupMenuItem(value: 9, child: Text('高 !!!')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
          ),
          // 移动到其他列表（TC-UI-119 / TC-API-118 同语义：跨列表移动清分区）
          _Row(
            icon: CupertinoIcons.folder,
            label: '列表',
            trailing: TextButton(
              key: const ValueKey('move_to_list'),
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
          const SizedBox(height: 20),

          // 子任务：真实列表（勾选/删除随流刷新）+ 新建草稿行
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 0,
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
                      child: const Icon(CupertinoIcons.delete,
                          color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteSubtask(sub.id),
                    child: ReminderRow(
                      item: sub,
                      dense: true,
                      onToggleCompleted: () =>
                          _repo.toggleCompleted(sub.id),
                    ),
                  ),
                if (_showSubtaskDraft)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.circle,
                            size: 18, color: Color(0xFFC7C7CC)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _subtask,
                            autofocus: true,
                            onSubmitted: (_) => _submitSubtask(),
                            decoration: const InputDecoration(
                              hintText: '子任务',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ListTile(
                  dense: true,
                  leading: const Icon(CupertinoIcons.add,
                      size: 20, color: Color(0xFF007AFF)),
                  title: Text(
                    subtasks.isEmpty ? '添加子任务' : '添加子任务',
                    style: const TextStyle(color: Color(0xFF007AFF)),
                  ),
                  onTap: () => setState(() => _showSubtaskDraft = true),
                ),
              ],
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

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.trailing});

  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      elevation: 0,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF007AFF), size: 22),
        title: Text(label),
        trailing: trailing,
      ),
    );
  }
}
