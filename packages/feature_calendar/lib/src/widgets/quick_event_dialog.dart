import 'package:app_ui/app_ui.dart';
import '../design/calendar_tokens.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:app_core/app_core.dart';

import '../nlp/quick_event_parser.dart';
import '../logic/event_time.dart';

/// 快速事件输入框（⌘N / 工具栏「＋」共用；契约 §6；F-12）。
///
/// 返回解析结果（UTC）；空串/取消回 null。Cupertino 化（#130）。
///
/// #620（TC-CAL-UI-204）：compact（<600）走**全屏页路由**，medium/expanded 仍是居中小对话框。
/// 判据只看宽度（契约 §8.5、AGENTS「布局只跟宽度；断点只换外壳，叶子不读断点」）——
/// 这个函数本身就是外壳级的呈现选择，字段表单 [_quickEventFields] 两边共用同一份。
Future<QuickEvent?> showQuickEventDialog(
  BuildContext context, {
  DateTime? now,
  int defaultDurationMinutes = 60,
  String timeZone = 'UTC',
}) {
  final resolvedNow = now ?? DateTime.now();
  if (MediaQuery.sizeOf(context).width < 600) {
    // 与 EventInspectorHost.openFullScreen 同一条路：push 用外层 context，
    // pop 必须用路由自己的 context（否则 pop 到壳分支根页 → go_router 断言白屏，#154）。
    return Navigator.of(context).push<QuickEvent>(
      CupertinoPageRoute<QuickEvent>(
        builder: (routeContext) => _QuickEventPage(
          now: resolvedNow,
          defaultDurationMinutes: defaultDurationMinutes,
          timeZone: timeZone,
          onResult: (quick) => Navigator.of(routeContext).pop(quick),
        ),
      ),
    );
  }
  return showCupertinoDialog<QuickEvent>(
    context: context,
    builder: (_) => _QuickEventDialog(
      now: resolvedNow,
      defaultDurationMinutes: defaultDurationMinutes,
      timeZone: timeZone,
    ),
  );
}

/// 输入框 + 解析预览（对话框与全屏页共用；两个 Key 保持与 #130 一致）。
///
/// 解析基准 `parsed` 由宿主算好传进来，`onChanged`/`onSubmitted` 也由宿主接
/// （前者触发重算、后者提交），所以这一份只是呈现，不持状态。
Widget _quickEventFields(
  BuildContext context, {
  required TextEditingController controller,
  required QuickEvent? parsed,
  required String timeZone,
  required String actionLabel,
  required VoidCallback onChanged,
  required VoidCallback onSubmitted,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 4),
      CupertinoTextField(
        key: const Key('quick_event_input'),
        controller: controller,
        autofocus: true,
        placeholder: '例如：明天下午3点开会',
        decoration: BoxDecoration(
          color: CalendarTokens.chipBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(LifeRadius.md),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        onChanged: (_) => onChanged(),
        onSubmitted: (_) => onSubmitted(),
      ),
      const SizedBox(height: 12),
      Text(
        parsed == null
            ? '输入内容后按「$actionLabel」'
            : '${parsed.title} · '
                  '${formatEventWall(parsed.startAt, timeZone, allDay: parsed.allDay)}',
        key: const Key('quick_event_preview'),
        style: const TextStyle(
          fontSize: 12,
          color: CalendarTokens.labelSecondary,
        ),
      ),
    ],
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

  void _submit() {
    final parsed = _parse();
    if (parsed != null) {
      Navigator.of(context).pop(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LifeAlertDialog(
      key: const Key('quick_event_dialog'),
      title: const Text('新建日程'),
      content: _quickEventFields(
        context,
        controller: _controller,
        parsed: _parse(),
        timeZone: widget.timeZone,
        actionLabel: '创建',
        onChanged: () => setState(() {}),
        onSubmitted: _submit,
      ),
      actions: [
        LifeDialogAction(
          key: const Key('quick_event_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        LifeDialogAction(
          key: const Key('quick_event_create'),
          isDefaultAction: true,
          onPressed: _submit,
          child: const Text('创建'),
        ),
      ],
    );
  }
}

/// iPhone 档的全屏新建页（#620）：顶部 取消/完成，字段逐段铺开。
class _QuickEventPage extends StatefulWidget {
  const _QuickEventPage({
    required this.now,
    required this.defaultDurationMinutes,
    required this.timeZone,
    required this.onResult,
  });

  final DateTime now;
  final int defaultDurationMinutes;
  final String timeZone;
  final ValueChanged<QuickEvent?> onResult;

  @override
  State<_QuickEventPage> createState() => _QuickEventPageState();
}

class _QuickEventPageState extends State<_QuickEventPage> {
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

  void _submit() {
    final parsed = _parse();
    if (parsed != null) {
      widget.onResult(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      key: const Key('quick_event_page'),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CalendarTokens.surface,
        middle: const Text('新建日程'),
        leading: CupertinoButton(
          key: const Key('quick_event_cancel'),
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          onPressed: () => widget.onResult(null),
          child: const Text('取消'),
        ),
        trailing: CupertinoButton(
          key: const Key('quick_event_create'),
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          onPressed: _submit,
          child: const Text(
            '完成',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _quickEventFields(
            context,
            controller: _controller,
            parsed: _parse(),
            timeZone: widget.timeZone,
            actionLabel: '完成',
            onChanged: () => setState(() {}),
            onSubmitted: _submit,
          ),
        ),
      ),
    );
  }
}
