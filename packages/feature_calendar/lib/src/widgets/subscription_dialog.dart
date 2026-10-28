import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:app_core/app_core.dart';

import '../logic/local_holidays.dart';

/// 本地订阅占位对话框（F-16）：只保存 URL，不发 HTTP。Cupertino 化（#130）。
Future<Calendar?> showLocalSubscriptionDialog(
  BuildContext context, {
  required CalendarRepository repository,
}) async {
  final url = await showCupertinoDialog<String>(
    context: context,
    builder: (_) => const _SubscriptionDialog(),
  );
  if (url == null) {
    return null;
  }
  return saveLocalSubscription(repository, url: url, title: '订阅');
}

class _SubscriptionDialog extends StatefulWidget {
  const _SubscriptionDialog();

  @override
  State<_SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<_SubscriptionDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LifeAlertDialog(
      key: const Key('subscription_dialog'),
      title: const Text('添加订阅日历'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          CupertinoTextField(
            key: const Key('subscription_url'),
            controller: _controller,
            placeholder: 'https://example.com/calendar.ics',
            decoration: BoxDecoration(
              color: const Color(0xFFE9E9EB),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '本地版只保存地址，不发起网络请求；登录后同步（F-17）。',
              key: Key('subscription_login_hint'),
              style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
          ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFFF3B30)),
              ),
            ),
        ],
      ),
      actions: [
        LifeDialogAction(
          key: const Key('subscription_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        LifeDialogAction(
          key: const Key('subscription_save'),
          isDefaultAction: true,
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      setState(() => _error = '请输入 http/https 订阅地址');
      return;
    }
    Navigator.of(context).pop(value);
  }
}
