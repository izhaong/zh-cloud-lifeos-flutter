/// #400 快捷键专用的两个临时面板：⇧⌘T 跳到日期、⌘I 日程信息。
///
/// 只由按键唤起、不进常驻布局树，因此不影响 golden 基线；控件形态沿
/// `LifeAlertDialog`（与订阅对话框同一套 Cupertino 弹窗）。
library;

import 'package:app_core/app_core.dart';
import 'package:app_ui/app_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../design/calendar_tokens.dart';

/// 跳到日期（Apple 的「跳到…」面板）：输入 `年-月-日`，回本地 DateTime。
Future<DateTime?> showJumpToDateDialog(
  BuildContext context, {
  required DateTime initial,
}) =>
    showCupertinoDialog<DateTime>(
      context: context,
      builder: (_) => _JumpToDateDialog(initial: initial),
    );

/// 日程信息（Apple ⌘I「显示信息」）：只读，不给编辑入口。
Future<void> showOccurrenceInfoDialog(
  BuildContext context, {
  required CalendarOccurrence occurrence,
}) =>
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => _OccurrenceInfoDialog(occurrence: occurrence),
    );

/// `2030-05-06` → `DateTime(2030, 5, 6)`；不合法回 null。
/// 用本地构造而非 `DateTime.parse`——后者把无时区串当 UTC，跨日会漂。
DateTime? parseJumpToDate(String raw) {
  final parts = raw.trim().split('-');
  if (parts.length != 3) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  return DateTime(year, month, day);
}

String _three(int value) => value.toString().padLeft(2, '0');

class _JumpToDateDialog extends StatefulWidget {
  const _JumpToDateDialog({required this.initial});

  final DateTime initial;

  @override
  State<_JumpToDateDialog> createState() => _JumpToDateDialogState();
}

class _JumpToDateDialogState extends State<_JumpToDateDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initial.year}-${_three(widget.initial.month)}'
        '-${_three(widget.initial.day)}',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LifeAlertDialog(
      key: const Key('jump_to_date_dialog'),
      title: const Text('跳到日期'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          CupertinoTextField(
            key: const Key('jump_to_date_field'),
            controller: _controller,
            placeholder: '2026-03-04',
            decoration: BoxDecoration(
              color: CalendarTokens.chipBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(LifeRadius.md),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '按「年-月-日」输入，例如 2026-03-04。',
              style: TextStyle(
                fontSize: 12,
                color: CalendarTokens.labelSecondary,
              ),
            ),
          ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
              ),
            ),
        ],
      ),
      actions: [
        LifeDialogAction(
          key: const Key('jump_to_date_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        LifeDialogAction(
          key: const Key('jump_to_date_go'),
          isDefaultAction: true,
          onPressed: _submit,
          child: const Text('跳到'),
        ),
      ],
    );
  }

  void _submit() {
    final parsed = parseJumpToDate(_controller.text);
    if (parsed == null) {
      setState(() => _error = '请输入「年-月-日」格式的日期');
      return;
    }
    Navigator.of(context).pop(parsed);
  }
}

class _OccurrenceInfoDialog extends StatelessWidget {
  const _OccurrenceInfoDialog({required this.occurrence});

  final CalendarOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final occ = occurrence;
    return LifeAlertDialog(
      key: const Key('occurrence_info_dialog'),
      title: Text(occ.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(_timeLabel(occ)),
          if (occ.location != null && occ.location!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(occ.location!),
          ],
        ],
      ),
      actions: [
        LifeDialogAction(
          key: const Key('occurrence_info_done'),
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('好'),
        ),
      ],
    );
  }

  String _timeLabel(CalendarOccurrence o) {
    if (o.allDay) {
      return '全天';
    }
    final start = o.start.toLocal();
    final end = o.end.toLocal();
    return '${start.month}/${start.day} '
        '${_three(start.hour)}:${_three(start.minute)}'
        ' – ${_three(end.hour)}:${_three(end.minute)}';
  }
}
