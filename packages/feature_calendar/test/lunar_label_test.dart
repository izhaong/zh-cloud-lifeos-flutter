import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// 农历标签口径（F-06；TC-CAL-UI-115 函数级自动化，UI 呈现走查）。
void main() {
  test('2026-02-17 春节 → 初一', () {
    expect(lunarDayLabel(DateTime(2026, 2, 17)), '初一');
    expect(isLunarFirstDay(DateTime(2026, 2, 17)), isTrue);
  });

  test('2026-02-18 → 初二（非初一）', () {
    expect(lunarDayLabel(DateTime(2026, 2, 18)), '初二');
    expect(isLunarFirstDay(DateTime(2026, 2, 18)), isFalse);
  });
}
