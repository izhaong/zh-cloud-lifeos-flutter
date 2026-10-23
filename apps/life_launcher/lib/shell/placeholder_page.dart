import 'package:flutter/material.dart';

/// 占位 Tab 页（feature_calendar / feature_habit 待拆入）。
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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(subtitle, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
