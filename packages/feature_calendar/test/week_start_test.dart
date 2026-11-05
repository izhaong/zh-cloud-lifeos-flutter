import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// #383 周起始偏好（0=跟随系统区域）；#468 改成可注入的纯函数。
void main() {
  test('#383 显式值 1..7 原样返回', () {
    for (var i = 1; i <= 7; i++) {
      expect(effectiveStartWeekOn(i), i);
    }
  });

  test('#383 0/越界 = 跟随给定区域', () {
    expect(effectiveStartWeekOn(0, localeTag: 'zh_CN'), DateTime.monday);
    expect(effectiveStartWeekOn(9, localeTag: 'zh_CN'), DateTime.monday);
    // en_US 以周日为一周之首（intl 的 FIRSTDAYOFWEEK=6 → +1 → 7）
    expect(effectiveStartWeekOn(0, localeTag: 'en_US'), DateTime.sunday);
  });

  test('#468 区域未知/为空/解析失败时回落周一（不让网格起点随环境漂）', () {
    expect(startWeekOnForLocale(null), DateTime.monday);
    expect(startWeekOnForLocale(''), DateTime.monday);
    expect(startWeekOnForLocale('   '), DateTime.monday);
    expect(startWeekOnForLocale('not a locale'), DateTime.monday);
  });

  test('#468 结果永远落在 1..7（kalender 只接受这个范围）', () {
    for (final tag in [null, '', 'zh_CN', 'en_US', 'ar_SA', 'ja_JP', 'de_DE']) {
      expect(startWeekOnForLocale(tag), inInclusiveRange(1, 7));
    }
  });

  test('#383 默认偏好为「跟随系统」', () {
    expect(const CalendarPreference().startWeekOn, 0);
  });
}
