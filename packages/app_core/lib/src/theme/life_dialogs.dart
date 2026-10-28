/// Cupertino 弹层的 CJK 回退补齐（#234）。
///
/// Flutter 的 `CupertinoAlertDialog` 标题/正文/按钮用的是 SDK 内常量样式
/// （`fontFamily: CupertinoSystemText`，`inherit: false`），既不读
/// `CupertinoThemeData.textTheme`，也不会继承外壳的 `DefaultTextStyle`；
/// Web（CanvasKit）上这些字没有中文回退就画方块。
///
/// 这里用 `DefaultTextStyle.merge` 在 SDK 常量样式**之下**再叠一层回退：
/// 顺序为 SDK 常量样式 → 本包装的合并样式 → 文本，回退才会生效。
library;

import 'package:cupertino_ui/cupertino_ui.dart';

import 'life_tokens.dart';

class LifeAlertDialog extends StatelessWidget {
  const LifeAlertDialog({
    super.key,
    this.title,
    this.content,
    required this.actions,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: title == null ? null : LifeDialogTextScope(child: title!),
      content: content == null ? null : LifeDialogTextScope(child: content!),
      actions: actions,
    );
  }
}

/// 给子树补 CJK 回退（不覆盖已有的显式字体与字号）。
class LifeDialogTextScope extends StatelessWidget {
  const LifeDialogTextScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: LifeTokens.dialogTextStyle,
      child: child,
    );
  }
}

/// `CupertinoDialogAction` 的替代：按钮文字同样补 CJK 回退。
class LifeDialogAction extends StatelessWidget {
  const LifeDialogAction({
    super.key,
    this.onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    this.textStyle,
    required this.child,
  });

  final VoidCallback? onPressed;
  final bool isDefaultAction;
  final bool isDestructiveAction;
  final TextStyle? textStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDefaultAction: isDefaultAction,
      isDestructiveAction: isDestructiveAction,
      textStyle: LifeTokens.dialogTextStyle.merge(textStyle),
      child: child,
    );
  }
}
