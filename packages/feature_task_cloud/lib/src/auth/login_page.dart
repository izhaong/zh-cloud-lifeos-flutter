import 'package:cupertino_ui/cupertino_ui.dart';

import 'package:app_core/app_core.dart';
import 'package:feature_task_cloud/src/auth/rest_auth_port.dart' show AuthFailureException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 登录页（TC-SYNC-102/103/104）：手机号+密码 → AuthPort.login；
/// 「跳过」直接返回——本地能力不受影响（§4.1 离线优先）。
class CloudLoginPage extends ConsumerStatefulWidget {
  const CloudLoginPage({super.key});

  @override
  ConsumerState<CloudLoginPage> createState() => _CloudLoginPageState();
}

class _CloudLoginPageState extends ConsumerState<CloudLoginPage> {
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authPortProvider).login(
            username: _mobile.text.trim(),
            password: _password.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailureException catch (e) {
      // TC-SYNC-104：明确失败提示；不落半登录态（AuthPort 契约保证）
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '网络异常，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _mobile.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('登录生活台'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(CupertinoIcons.cloud_fill,
                  size: 56, color: Color(0xFF007AFF)),
              const SizedBox(height: 12),
              const Text(
                '云同步',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                '登录后多端同步提醒事项；跳过不影响本地使用',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
              const SizedBox(height: 24),
              CupertinoTextField(
                key: const ValueKey('login_mobile'),
                controller: _mobile,
                placeholder: '手机号',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                key: const ValueKey('login_password'),
                controller: _password,
                placeholder: '密码',
                obscureText: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const ValueKey('login_error'),
                  style: const TextStyle(fontSize: 13, color: Color(0xFFFF3B30)),
                ),
              ],
              const SizedBox(height: 24),
              CupertinoButton.filled(
                key: const ValueKey('login_submit'),
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? '登录中…' : '登录'),
              ),
              CupertinoButton(
                key: const ValueKey('login_skip'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('跳过'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
