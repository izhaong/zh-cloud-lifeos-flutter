import 'package:app_ui/app_ui.dart';
import '../design/calendar_tokens.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:app_core/app_core.dart';

import '../logic/local_holidays.dart';
import '../logic/subscription_import.dart';
import '../providers.dart';

/// 添加订阅对话框（F-16 / #403）。
///
/// 保存后**立即拉取并落库**（需要注入 [SubscriptionFetcher]）；未注入抓取端口时
/// 仍保存 URL，但返回 `pending: true`，由调用方如实告知「内容待联网同步」——
/// 不再像此前那样静默存个 URL 就完事（订阅后永远没事件）。
Future<SubscriptionImportResult?> showLocalSubscriptionDialog(
  BuildContext context, {
  required CalendarRepository repository,
  SubscriptionFetcher? fetcher,
  DateTime Function()? clock,
}) async {
  final url = await showCupertinoDialog<String>(
    context: context,
    builder: (_) => const _SubscriptionDialog(),
  );
  if (url == null) {
    return null;
  }
  final calendar =
      await saveLocalSubscription(repository, url: url, title: '订阅');
  if (fetcher == null) {
    return const SubscriptionImportResult.pending();
  }
  return refreshSubscription(
    repository: repository,
    calendar: calendar,
    fetcher: fetcher,
    clock: clock ?? DateTime.now,
  );
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
              color: CalendarTokens.chipBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(LifeRadius.md),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '本地版只保存地址，不发起网络请求；登录后同步（F-17）。',
              key: Key('subscription_login_hint'),
              style: TextStyle(fontSize: 12, color: CalendarTokens.labelSecondary),
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
