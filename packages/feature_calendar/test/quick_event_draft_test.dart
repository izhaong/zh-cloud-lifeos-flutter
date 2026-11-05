import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// #219 快速新建全天日程的日期归属（TC-CAL-UI-138 / 矩阵 E1·H1·I14）。
void main() {
  const ny = 'America/New_York';

  test('#219 未写日期的全天事件锚到设备本地当天', () {
    // 解析时刻给成 UTC 午夜：UTC-4 宿主上渲染就是前一天 20:00
    final quick = QuickEvent(
      title: '牙医复诊',
      startAt: DateTime.utc(2026, 10, 28),
      endAt: DateTime.utc(2026, 10, 29),
      allDay: true,
      dateExplicit: false,
    );

    final draft = quickEventDraft(
      quick,
      timeZone: ny,
      now: DateTime(2026, 10, 28, 2, 46),
    );

    expect(draft.allDay, isTrue);
    expect(formatEventWall(draft.startAt, ny, allDay: true), '2026-10-28');
    expect(formatEventWall(draft.endAt, ny, allDay: true), '2026-10-29');
    expect(draft.startAt, utcFromWall(DateTime(2026, 10, 28), ny));
    expect(draft.timeZone, ny);
  });

  test('#219 写了日期的全天事件保持原日期', () {
    final quick = QuickEvent(
      title: '发布会',
      startAt: utcFromWall(DateTime(2026, 11, 5), ny),
      endAt: utcFromWall(DateTime(2026, 11, 6), ny),
      allDay: true,
      dateExplicit: true,
    );

    final draft = quickEventDraft(
      quick,
      timeZone: ny,
      now: DateTime(2026, 10, 28, 2, 46),
    );

    expect(formatEventWall(draft.startAt, ny, allDay: true), '2026-11-05');
  });

  test('#219 定时事件不受重锚影响', () {
    final start = utcFromWall(DateTime(2026, 10, 28, 15), ny);
    final quick = QuickEvent(
      title: '评审',
      startAt: start,
      endAt: start.add(const Duration(hours: 1)),
      allDay: false,
      dateExplicit: false,
    );

    final draft = quickEventDraft(
      quick,
      timeZone: ny,
      now: DateTime(2026, 10, 28, 2, 46),
    );

    expect(draft.startAt, start);
    expect(draft.allDay, isFalse);
  });

  test('#219 解析器区分「写没写日期」', () {
    final now = DateTime(2026, 10, 28, 9);

    final noDate = parseQuickEvent('牙医复诊', now: now, timeZone: 'UTC');
    expect(noDate!.allDay, isTrue);
    expect(noDate.dateExplicit, isFalse);

    final tomorrow = parseQuickEvent('明天 牙医复诊', now: now, timeZone: 'UTC');
    expect(tomorrow!.allDay, isTrue);
    expect(tomorrow.dateExplicit, isTrue);
  });
}
