import 'package:cupertino_ui/cupertino_ui.dart';

/// 未知路由兜底页（parity#187）。
///
/// go_router 默认 error 页是英文 Material 版，还会把
/// `GoException: no routes for location: …` 原文直接糊在用户脸上。
/// 这里给一个与壳一致的 Cupertino 中文兜底，且**不回显任何异常原文**。
class RouteNotFoundPage extends StatelessWidget {
  const RouteNotFoundPage({super.key, this.onHome});

  /// 「返回首页」回调（缺省由调用方注入 `context.go('/')`）。
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.compass,
                size: 44,
                color: CupertinoColors.tertiaryLabel,
              ),
              const SizedBox(height: 12),
              const Text(
                '页面不存在',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                '这个地址打不开，可能已被移除。',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                key: const ValueKey('route_not_found_home'),
                onPressed: onHome,
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
