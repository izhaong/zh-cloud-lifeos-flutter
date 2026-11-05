/// 日历搜索过滤（契约「搜索框过滤当前窗口标题/地点/备注」；F-13）。
library;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

bool matchesCalendarSearch(CalendarEvent event, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return true;
  }
  return event.title.toLowerCase().contains(q) ||
      (event.location ?? '').toLowerCase().contains(q) ||
      (event.notes ?? '').toLowerCase().contains(q);
}
