// TC-CAL-API/C1 订阅日历（#403）：ICS 解析。
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('#403 解析单个定时事件（UTC）', () {
    final result = parseIcs('''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:abc-1
SUMMARY:周会
DTSTART:20261029T090000Z
DTEND:20261029T100000Z
END:VEVENT
END:VCALENDAR''');

    expect(result.skipped, 0);
    final event = result.events.single;
    expect(event.uid, 'abc-1');
    expect(event.title, '周会');
    expect(event.allDay, isFalse);
    expect(event.start.toUtc(), DateTime.utc(2026, 10, 29, 9));
  });

  test('#403 解析全天事件（VALUE=DATE）', () {
    final result = parseIcs('''
BEGIN:VEVENT
UID:abc-2
SUMMARY:假期
DTSTART;VALUE=DATE:20261029
DTEND;VALUE=DATE:20261030
END:VEVENT''');

    final event = result.events.single;
    expect(event.allDay, isTrue);
    expect(event.start, DateTime(2026, 10, 29));
  });

  test('#403 行折叠（续行以空格开头）要拼回一条', () {
    final result = parseIcs('''
BEGIN:VEVENT
UID:fold-1
SUMMARY:这是一个很长
 的标题
DTSTART:20261029T090000Z
END:VEVENT''');

    expect(result.events.single.title, '这是一个很长的标题');
  });

  test('#403 文本转义（\\n 换行、\\, 逗号）', () {
    final result = parseIcs(r'''
BEGIN:VEVENT
UID:esc-1
SUMMARY:早餐\, 午餐
DESCRIPTION:第一行\n第二行
DTSTART:20261029T090000Z
END:VEVENT''');

    final event = result.events.single;
    expect(event.title, '早餐, 午餐');
    expect(event.description, '第一行\n第二行');
  });

  test('#403 多条事件都解析，顺序保持', () {
    final result = parseIcs('''
BEGIN:VEVENT
UID:a
SUMMARY:第一条
DTSTART:20261029T090000Z
END:VEVENT
BEGIN:VEVENT
UID:b
SUMMARY:第二条
DTSTART:20261030T090000Z
END:VEVENT''');

    expect(result.events.map((e) => e.uid), ['a', 'b']);
  });

  test('#403 缺 DTSTART 的 VEVENT 跳过并计数（不猜时间）', () {
    final result = parseIcs('''
BEGIN:VEVENT
UID:bad
SUMMARY:没有开始时间
END:VEVENT''');

    expect(result.events, isEmpty);
    expect(result.skipped, 1);
  });

  test('#403 带 RRULE 的重复事件跳过（本卡不展开，避免给出错误时间）', () {
    final result = parseIcs('''
BEGIN:VEVENT
UID:rrule-1
SUMMARY:每周
DTSTART:20261029T090000Z
RRULE:FREQ=WEEKLY
END:VEVENT''');

    expect(result.events, isEmpty);
    expect(result.skipped, 1);
  });

  test('#403 空输入不抛', () {
    final result = parseIcs('');
    expect(result.events, isEmpty);
    expect(result.skipped, 0);
  });
}
