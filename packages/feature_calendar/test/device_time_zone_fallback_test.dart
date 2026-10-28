import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// #297：Web 端 `flutter_timezone` 不可用时的时区兜底。
///
/// 兜底目标是「不要退成 UTC」——UTC 会让网格（本地）与详情（事件时区）差一个
/// 偏移；用当前 UTC 偏移合成 `Etc/GMT∓N` 至少保证同一时刻两边一致。
void main() {
  test('兜底链至少给出一个 tz 库里存在的时区名（不是空串）', () async {
    final name = await deviceTimeZoneName();
    expect(name, isNotEmpty);
    expect(allTimeZoneNames(), contains(name));
  });

  test('本机偏移与兜底时区解算出的偏移一致（不是 UTC 一刀切）', () async {
    final name = await deviceTimeZoneName();
    final wall = wallTimeOf(DateTime.now(), name);
    final local = DateTime.now();
    expect(
      wall.timeZoneOffset,
      local.timeZoneOffset,
      reason: '设备时区必须与宿主偏移一致；退成 UTC 时这里会差一个偏移（#297）',
    );
  });
}
