import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../providers.dart';

/// 迷你月历（契约 §5.4；F-04）。
///
/// medium/expanded 侧栏与 iPhone 月条共用；点日期改 anchorDateProvider；
/// 周起始按偏好 startWeekOn（默认周一）。
class MiniMonth extends ConsumerWidget {
  const MiniMonth({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchor = ref.watch(anchorDateProvider);
    final preference = ref.watch(preferenceProvider).value;
    final weekStart = preference?.startWeekOn ?? 1;
    return TableCalendar(
      firstDay: DateTime(anchor.year - 2, anchor.month, 1),
      lastDay: DateTime(anchor.year + 2, anchor.month, 1),
      focusedDay: anchor,
      startingDayOfWeek:
          weekStart == 7 ? StartingDayOfWeek.sunday : StartingDayOfWeek.monday,
      selectedDayPredicate: (day) =>
          day.year == anchor.year && day.month == anchor.month && day.day == anchor.day,
      onDaySelected: (selected, focused) {
        ref.read(anchorDateProvider.notifier).set(
              DateTime(selected.year, selected.month, selected.day),
            );
      },
      onPageChanged: (focused) {
        ref.read(anchorDateProvider.notifier).set(
              DateTime(focused.year, focused.month, focused.day),
            );
      },
      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      calendarStyle: const CalendarStyle(outsideDaysVisible: false),
      availableGestures: AvailableGestures.horizontalSwipe,
    );
  }
}
