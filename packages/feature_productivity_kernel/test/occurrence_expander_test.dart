// TC-CAL-KR-102 / TC-CAL-KR-201～209：日历 occurrence 展开纯函数（契约 §5.2、F-01）。
//
// TC-CAL-KR-201～209 与服务端 ical4j（S-07）共用同一份夹具
// test/fixtures/recurrence_cases.json（服务端副本：
// zh-cloud-service/yudao-module-lifeos-calendar/src/test/resources/lifeos-calendar/），
// 期望值以 RFC 5545 / ical4j 为准。时间一律 UTC；窗口 [from, to) 右开。
import 'dart:convert';
import 'dart:io';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _event({
  required String id,
  required String calendarId,
  required DateTime startAt,
  required DateTime endAt,
  String? rrule,
  List<DateTime> exdates = const [],
  String? parentEventId,
  DateTime? originalStartAt,
  String title = '日程',
}) {
  return CalendarEvent(
    id: id,
    calendarId: calendarId,
    uid: 'uid-$id',
    title: title,
    startAt: startAt,
    endAt: endAt,
    timeZone: 'Asia/Shanghai',
    updatedAt: DateTime.utc(2026, 10, 24),
    rrule: rrule,
    exdates: exdates,
    parentEventId: parentEventId,
    originalStartAt: originalStartAt,
  );
}

void main() {
  group('expandOccurrences · 单次事件', () {
    // TC-CAL-KR-102：跨日定时事件只展开一条，UTC 差 3 小时（上海 22:00 → 次日 01:00）。
    test('TC-CAL-KR-102 跨日定时', () {
      final occ = expandOccurrences(
        [
          _event(
            id: 'e1',
            calendarId: 'cal1',
            startAt: DateTime.utc(2026, 11, 3, 14),
            endAt: DateTime.utc(2026, 11, 3, 17),
          ),
        ],
        from: DateTime.utc(2026, 11, 1),
        to: DateTime.utc(2026, 11, 8),
        colorByCalendar: const {'cal1': 0xFF007AFF},
      );
      expect(occ, hasLength(1));
      expect(occ.single.start, DateTime.utc(2026, 11, 3, 14));
      expect(occ.single.end, DateTime.utc(2026, 11, 3, 17));
      expect(
          occ.single.end.difference(occ.single.start), const Duration(hours: 3));
      expect(occ.single.isRecurring, isFalse);
      expect(occ.single.isException, isFalse);
      expect(occ.single.source, OccurrenceSource.event);
      expect(occ.single.masterEventId, 'e1');
      expect(occ.single.colorArgb, 0xFF007AFF);
      // 上海（UTC+8）墙上时间：22:00 → 次日 01:00
      expect(occ.single.start.add(const Duration(hours: 8)).hour, 22);
      final shanghaiEnd = occ.single.end.add(const Duration(hours: 8));
      expect(shanghaiEnd.day, 4);
      expect(shanghaiEnd.hour, 1);
    });

    test('单次事件与窗口部分重叠仍呈现、恰好贴边不呈现', () {
      final occ = expandOccurrences(
        [
          // 11-03 22:00 → 11-05 02:00（跨三日），窗口只盖 11-04 一天
          _event(
            id: 'e2',
            calendarId: 'cal1',
            startAt: DateTime.utc(2026, 11, 3, 22),
            endAt: DateTime.utc(2026, 11, 5, 2),
          ),
          // 恰好在窗口左边界结束：不呈现
          _event(
            id: 'e3',
            calendarId: 'cal1',
            startAt: DateTime.utc(2026, 11, 3),
            endAt: DateTime.utc(2026, 11, 4),
          ),
        ],
        from: DateTime.utc(2026, 11, 4),
        to: DateTime.utc(2026, 11, 5),
        colorByCalendar: const {'cal1': 0xFF007AFF},
      );
      expect(occ.map((o) => o.eventId), ['e2']);
    });
  });

  // TC-CAL-KR-201～209：夹具驱动，每条用例一个 test（与服务端 S-07 同一份期望）。
  final fixture = jsonDecode(
    File('test/fixtures/recurrence_cases.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  for (final raw in fixture['cases'] as List) {
    final c = raw as Map<String, dynamic>;
    final id = c['id'] as String;
    test(id, () {
      final masterId = '$id-master';
      final master = _event(
        id: masterId,
        calendarId: 'cal1',
        startAt: DateTime.parse(c['start'] as String),
        endAt: DateTime.parse(c['start'] as String)
            .add(Duration(minutes: c['durationMinutes'] as int)),
        rrule: c['rrule'] as String,
        exdates: (c['exdates'] as List<dynamic>? ?? const [])
            .map((e) => DateTime.parse(e as String))
            .toList(),
      );
      final exceptions = (c['exceptions'] as List<dynamic>? ?? const [])
          .map((x) => _event(
                id: '$id-ex-${x['originalStart']}',
                calendarId: 'cal1',
                startAt: DateTime.parse(x['start'] as String),
                endAt: DateTime.parse(x['end'] as String),
                parentEventId: masterId,
                originalStartAt: DateTime.parse(x['originalStart'] as String),
                title: x['title'] as String,
              ))
          .toList();

      final occ = expandOccurrences(
        [master, ...exceptions],
        from: DateTime.parse(c['windowFrom'] as String),
        to: DateTime.parse(c['windowTo'] as String),
        colorByCalendar: const {'cal1': 0xFF34C759},
      );

      expect(
        occ.map((o) => o.start.toIso8601String()).toList(),
        (c['expectedStarts'] as List).map((e) => DateTime.parse(e as String).toIso8601String()).toList(),
        reason: '$id 期望 occurrence 开始时间',
      );
      expect(occ.every((o) => o.isRecurring), isTrue,
          reason: '$id 均来自重复主记录');
      expect(occ.every((o) => o.colorArgb == 0xFF34C759), isTrue);

      // TC-CAL-KR-209：例外次以例外行的标题/时间呈现，其余次保持主记录。
      for (final o in occ.where((o) => o.isException)) {
        expect(o.masterEventId, masterId);
        expect(o.eventId, isNot(masterId));
        expect(o.title, '改期');
        expect(o.start, DateTime.parse('2026-11-02T14:00:00Z'));
        expect(o.end, DateTime.parse('2026-11-02T15:00:00Z'));
      }
    });
  }
}
