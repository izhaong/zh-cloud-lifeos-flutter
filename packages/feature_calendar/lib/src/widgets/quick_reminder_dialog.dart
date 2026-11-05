import 'package:app_ui/app_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../design/calendar_tokens.dart';
import '../nlp/quick_event_parser.dart';
import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

/// 快速新建提醒的落点（#401）：解析结果 + 用户指定的目标列表。
typedef QuickReminderDraft = ({QuickEvent event, String listId});

/// 快速新建提醒输入框（工具栏「＋ → 新建提醒」；TC-CAL-UI-191）。
///
/// #401：此前列表落点恒为第一个普通列表（用户无从指定）。这里把候选列表
/// 直接摊在面板里（Apple 的新建面板就带「列表」这一行），智能列表不参与
/// （Issue「非目标」）。取消回 null。
Future<QuickReminderDraft?> showQuickReminderDialog(
  BuildContext context, {
  required List<ReminderList> lists,
  DateTime? now,
  String timeZone = 'UTC',
}) {
  return showCupertinoDialog<QuickReminderDraft>(
    context: context,
    builder: (_) => _QuickReminderDialog(
      lists: lists,
      now: now ?? DateTime.now(),
      timeZone: timeZone,
    ),
  );
}

class _QuickReminderDialog extends StatefulWidget {
  const _QuickReminderDialog({
    required this.lists,
    required this.now,
    required this.timeZone,
  });

  final List<ReminderList> lists;
  final DateTime now;
  final String timeZone;

  @override
  State<_QuickReminderDialog> createState() => _QuickReminderDialogState();
}

class _QuickReminderDialogState extends State<_QuickReminderDialog> {
  final _controller = TextEditingController();
  late String _listId = widget.lists.first.id;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  QuickEvent? _parse() => parseQuickEvent(
    _controller.text,
    now: widget.now,
    defaultDurationMinutes: 30,
    timeZone: widget.timeZone,
  );

  @override
  Widget build(BuildContext context) {
    return LifeAlertDialog(
      key: const Key('quick_reminder_dialog'),
      title: const Text('新建提醒'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          CupertinoTextField(
            key: const Key('quick_reminder_input'),
            controller: _controller,
            autofocus: true,
            placeholder: '例如：明天下午3点取快递',
            decoration: BoxDecoration(
              color: CalendarTokens.chipBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(LifeRadius.md),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          _listRow(),
        ],
      ),
      actions: [
        LifeDialogAction(
          key: const Key('quick_reminder_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        LifeDialogAction(
          key: const Key('quick_reminder_create'),
          isDefaultAction: true,
          onPressed: _submit,
          child: const Text('创建'),
        ),
      ],
    );
  }

  /// 目标列表行：多于一个候选时逐个可点；只有一个时也要显出落点，
  /// 否则用户不知道提醒写到了哪里。
  Widget _listRow() {
    const label = Text(
      '列表',
      key: Key('quick_reminder_list_label'),
      style: TextStyle(fontSize: 12, color: CalendarTokens.labelSecondary),
    );
    if (widget.lists.length < 2) {
      return Row(
        children: [
          label,
          const SizedBox(width: 8),
          Text(
            widget.lists.first.title,
            key: const Key('quick_reminder_list_static'),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [label, for (final l in widget.lists) _chip(l)],
    );
  }

  Widget _chip(ReminderList list) {
    final selected = list.id == _listId;
    return CupertinoButton(
      key: Key('quick_reminder_list_${list.id}'),
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: selected
          ? CalendarTokens.systemBlue
          : CalendarTokens.chipBackground.resolveFrom(context),
      borderRadius: BorderRadius.circular(LifeRadius.md),
      onPressed: () => setState(() => _listId = list.id),
      child: Text(
        list.title,
        style: TextStyle(
          fontSize: 12,
          color: selected ? CupertinoColors.white : CalendarTokens.labelStrong,
        ),
      ),
    );
  }

  void _submit() {
    final parsed = _parse();
    if (parsed != null) {
      Navigator.of(context).pop((event: parsed, listId: _listId));
    }
  }
}
