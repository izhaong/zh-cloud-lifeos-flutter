import 'package:flutter/material.dart';

import 'calendar_scaffold.dart';

/// 壳接入点（契约 §5.5：替换 /calendar 的 PlaceholderPage）。
class CalendarTabEntry extends StatelessWidget {
  const CalendarTabEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return const CalendarScaffold();
  }
}
