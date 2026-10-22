import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';


/// 「详细信息」编辑面板（Apple 提醒事项对齐：备注 / 日期与时间 / 重复 /
/// 标记(旗标) / 标签 / 优先级 / 子任务）。
///
/// 布局无关：紧凑端模态全屏页、宽屏第三栏共用；
/// 每次提交 = copyWith + onSaved(item)（由上层调 upsertItem 全量回写）。
class ReminderDetailPane extends StatefulWidget {
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
  State<ReminderDetailPane> createState() => _ReminderDetailPaneState();
}

class _ReminderDetailPaneState extends State<ReminderDetailPane> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _tags;
  late bool _isFlagged;
  late int _priority;
  late String? _recurrence;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item.title);
    _notes = TextEditingController(text: widget.item.notes ?? '');
    _tags = TextEditingController(text: widget.item.tags.join(', '));
    _isFlagged = widget.item.isFlagged;
    _priority = widget.item.priority;
    _recurrence = widget.item.recurrence;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _tags.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
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

          // 日期与时间（展示；编辑入口 Phase 3 完整日历选择）
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
          const SizedBox(height: 20),

          // 子任务（Phase 2 只读计数展示；新建/勾选子任务随后续小步）
          const _Row(
            icon: CupertinoIcons.checkmark_circle,
            label: '子任务',
            trailing: Text('2 项 ›'),
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
