import 'dart:ui';

import 'package:intl/intl.dart';

/// 系统区域的首个工作日（1=周一…7=周日）。
///
/// intl 的 `FIRSTDAYOFWEEK` 以 0=周日编码；系统区域为未知 locale 时回退周一。
int systemStartWeekOn() {
  final tag = PlatformDispatcher.instance.locale.toLanguageTag();
  try {
    final first = DateFormat.yMd(tag).dateSymbols.FIRSTDAYOFWEEK;
    return first == 0 ? DateTime.sunday : first;
  } catch (_) {
    return DateTime.monday;
  }
}

/// 偏好值 → 生效的周起始：`0`=跟随系统；`1..7`=显式（1 周一 / 7 周日）。
int effectiveStartWeekOn(int raw) =>
    raw >= 1 && raw <= 7 ? raw : systemStartWeekOn();
