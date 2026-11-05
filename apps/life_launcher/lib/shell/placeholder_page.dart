import 'package:cupertino_ui/cupertino_ui.dart';

/// 占位 Tab 页（feature_habit 待拆入）。
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(title)),
      child: Center(
        child: Text(
          subtitle,
          style: CupertinoTheme.of(context)
              .textTheme
              .navTitleTextStyle
              .copyWith(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
        ),
      ),
    );
  }
}
