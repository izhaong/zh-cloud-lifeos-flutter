import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// F-12 自然语言快速事件（TC-CAL-KR-301～310；契约 §6）。
void main() {
  // 参考日 2026-10-24 周六 09:00（UTC，便于断言）
  final now = DateTime.utc(2026, 10, 24, 9);

  QuickEvent? parse(String s) =>
      parseQuickEvent(s, now: now, timeZone: 'UTC');

  test('TC-CAL-KR-301 英文月日', () {
    final r = parse('Party Feb 6')!;
    expect(r.title, 'Party');
    expect(r.allDay, isTrue);
    expect(r.startAt, DateTime.utc(2027, 2, 6), reason: '2026-02-06 已过');
    expect(r.endAt, DateTime.utc(2027, 2, 7));
  });

  test('TC-CAL-KR-302 英文星期+时间段（当天未过 → 今天）', () {
    final r = parse('Soccer Game on Saturday from 11am-1pm')!;
    expect(r.title, 'Soccer Game');
    expect(r.allDay, isFalse);
    expect(r.startAt, DateTime.utc(2026, 10, 24, 11));
    expect(r.endAt, DateTime.utc(2026, 10, 24, 13));
  });

  test('TC-CAL-KR-302b 当天已过 → 下周六', () {
    final late = DateTime.utc(2026, 10, 24, 14);
    final r = parseQuickEvent('Soccer Game on Saturday from 11am-1pm',
        now: late, timeZone: 'UTC')!;
    expect(r.startAt, DateTime.utc(2026, 10, 31, 11));
  });

  test('TC-CAL-KR-303 英文多日（下周一到周五）', () {
    final r = parse('Vacation in Bahamas Mon-Fri')!;
    expect(r.title, 'Vacation in Bahamas');
    expect(r.allDay, isTrue);
    expect(r.startAt, DateTime.utc(2026, 10, 26), reason: '下一个周一');
    expect(r.endAt, DateTime.utc(2026, 10, 31), reason: '周六 00:00 排他');
  });

  test('TC-CAL-KR-304 明天下午3点 + 默认时长', () {
    final r = parse('明天下午3点开会')!;
    expect(r.title, '开会');
    expect(r.startAt, DateTime.utc(2026, 10, 25, 15));
    expect(r.endAt, DateTime.utc(2026, 10, 25, 16));
  });

  test('TC-CAL-KR-305 中文星期+时分', () {
    final r = parse('周五 9:30-10:30 周会')!;
    expect(r.title, '周会');
    expect(r.startAt, DateTime.utc(2026, 10, 30, 9, 30));
    expect(r.endAt, DateTime.utc(2026, 10, 30, 10, 30));
  });

  test('TC-CAL-KR-306 中文月日无时间 → 全天', () {
    final r = parse('11月3日 牙医')!;
    expect(r.title, '牙医');
    expect(r.allDay, isTrue);
    expect(r.startAt, DateTime.utc(2026, 11, 3));
  });

  test('TC-CAL-KR-307 无法解析 → 整串标题 + 今天全天', () {
    final r = parse('随便写点什么')!;
    expect(r.title, '随便写点什么');
    expect(r.allDay, isTrue);
    expect(r.startAt, DateTime.utc(2026, 10, 24));
  });

  test('TC-CAL-KR-308 今天下午2点', () {
    final r = parse('今天下午2点 复盘')!;
    expect(r.title, '复盘');
    expect(r.startAt, DateTime.utc(2026, 10, 24, 14));
  });

  test('TC-CAL-KR-309 时长写法 6-7 → 傍晚', () {
    final r = parse('Dinner at 6-7')!;
    expect(r.title, 'Dinner');
    expect(r.startAt, DateTime.utc(2026, 10, 24, 18));
    expect(r.endAt, DateTime.utc(2026, 10, 24, 19));
  });

  test('TC-CAL-KR-310 空串 → null', () {
    expect(parse(''), isNull);
    expect(parse('   '), isNull);
  });
}
