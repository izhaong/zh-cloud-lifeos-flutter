import 'package:lunar/lunar.dart';

/// 农历日标签（契约 C-154；F-06）。
///
/// 例：正月初一 → 「初一」；月视图在日期数字下显示该标签，初一用红色。
String lunarDayLabel(DateTime date) {
  return Lunar.fromDate(date).getDayInChinese();
}

/// 是否农历初一（月视图红色显示）。
bool isLunarFirstDay(DateTime date) {
  return lunarDayLabel(date) == '初一';
}

/// 农历年月日（日视图大标题右侧；例：丙午年九月十八）。
String lunarDateLabel(DateTime date) {
  final lunar = Lunar.fromDate(date);
  return '${lunar.getYearInGanZhi()}年'
      '${lunar.getMonthInChinese()}月'
      '${lunar.getDayInChinese()}';
}
