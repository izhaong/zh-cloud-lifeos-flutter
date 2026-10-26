import 'package:flutter/material.dart';

import '../nlp/quick_event_parser.dart';
import '../logic/event_time.dart';

/// 快速事件输入框（⌘N / 工具栏「＋」共用；契约 §6；F-12）。
///
/// 返回解析结果（UTC）；空串/取消回 null。
Future<QuickEvent?> showQuickEventDialog(
  BuildContext context, {
  DateTime? now,
  int defaultDurationMinutes = 60,
  String timeZone = 'UTC',
}) {
  return showDialog<QuickEvent>(
    context: context,
    builder: (_) => _QuickEventDialog(
      now: now ?? DateTime.now(),
      defaultDurationMinutes: defaultDurationMinutes,
      timeZone: timeZone,
    ),
  );
}

class _QuickEventDialog extends StatefulWidget {
  const _QuickEventDialog({
    required this.now,
    required this.defaultDurationMinutes,
    required this.timeZone,
  });

  final DateTime now;
  final int defaultDurationMinutes;
  final String timeZone;

  @override
  State<_QuickEventDialog> createState() => _QuickEventDialogState();
}

class _QuickEventDialogState extends State<_QuickEventDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  QuickEvent? _parse() => parseQuickEvent(
        _controller.text,
        now: widget.now,
        defaultDurationMinutes: widget.defaultDurationMinutes,
        timeZone: widget.timeZone,
      );

  @override
  Widget build(BuildContext context) {
    final parsed = _parse();
    return AlertDialog(
      key: const Key('quick_event_dialog'),
      title: const Text('新建日程'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('quick_event_input'),
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '例如：明天下午3点开会',
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              parsed == null
                  ? '输入内容后按「创建」'
                  : '${parsed.title} · '
                      '${formatEventWall(parsed.startAt, widget.timeZone, allDay: parsed.allDay)}',
              key: const Key('quick_event_preview'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('quick_event_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('quick_event_create'),
          onPressed: _submit,
          child: const Text('创建'),
        ),
      ],
    );
  }

  void _submit() {
    final parsed = _parse();
    if (parsed != null) {
      Navigator.of(context).pop(parsed);
    }
  }
}
