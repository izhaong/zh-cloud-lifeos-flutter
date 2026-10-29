import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// #383：周起始偏好 0=跟随系统区域。
void main() {
  test('#383 effectiveStartWeekOn：0/越界=跟随系统，1..7 原样', () {
    expect(effectiveStartWeekOn(1), 1);
    expect(effectiveStartWeekOn(7), 7);
    final system = systemStartWeekOn();
    expect(system, inInclusiveRange(1, 7), reason: '系统周起始应落在周一..周日');
    expect(effectiveStartWeekOn(0), system, reason: '0 必须解析为系统值');
    expect(effectiveStartWeekOn(9), system, reason: '越界值回退系统值');
  });

  test('#383 默认偏好为「跟随系统」', () {
    expect(const CalendarPreference().startWeekOn, 0);
  });
}
