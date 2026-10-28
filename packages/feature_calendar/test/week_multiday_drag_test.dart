import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// #240 / 矩阵 E2：周视图横拖跨多日要生成**覆盖所选日期**的多日全天草稿。
///
/// 旧实现把拖选交给 `onDraftCreate(start, end)`，而它按「起始 + 偏好默认时长」
/// 造 1 小时草稿，终点被丢弃 —— 这就是实测里「拖周一到周三只得到周一 00:00–01:00」
/// 的成因。这里钉住分派判据与草稿跨度。
void main() {
  late CalendarEvent? draft;

  CalendarViewCallbacks callbacks() => CalendarViewCallbacks(
        repo: _NoopRepo(),
        preference: const CalendarPreference(),
        timeZone: 'America/New_York',
        setDraft: (d) => draft = d,
      );

  setUp(() => draft = null);

  group('#240 拖拽创建分派', () {
    test('定时网格里横拖 周一10:00 → 周三10:00 = 周一～周三全天（终点按包含）', () {
      callbacks().onDragCreate(
        DateTime(2026, 10, 26, 10),
        DateTime(2026, 10, 28, 10),
      );
      expect(draft, isNotNull);
      expect(draft!.allDay, isTrue, reason: '跨多日的拖选按全天处理（Apple 周视图）');
      // 10/26 00:00 EDT → 04:00Z；排他终点 10/29 00:00 EDT → 04:00Z
      expect(draft!.startAt, DateTime.utc(2026, 10, 26, 4));
      expect(draft!.endAt, DateTime.utc(2026, 10, 29, 4),
          reason: '终点要含周三（拖进周三即周三在范围内）');
    });

    test('终点正好是零点时不补一天（拖满整日边界）', () {
      callbacks().onDragCreate(
        DateTime(2026, 10, 26, 0),
        DateTime(2026, 10, 28, 0),
      );
      expect(draft!.allDay, isTrue);
      expect(draft!.startAt, DateTime.utc(2026, 10, 26, 4));
      expect(draft!.endAt, DateTime.utc(2026, 10, 28, 4),
          reason: '零点终点已排他，补一天会多算周三');
    });

    test('全天区拖选保持 parity#228 口径（不重复补天）', () {
      callbacks().onDragCreate(
        DateTime(2026, 10, 26),
        DateTime(2026, 10, 28),
      );
      expect(draft!.allDay, isTrue);
      expect(draft!.endAt, DateTime.utc(2026, 10, 28, 4));
    });

    test('同日内拖选仍是定时草稿且时长=偏好默认（TC-CAL-UI-130 不回归）', () {
      callbacks().onDragCreate(
        DateTime(2026, 10, 26, 10),
        DateTime(2026, 10, 26, 15),
      );
      expect(draft!.allDay, isFalse);
      expect(draft!.startAt.toLocal(), DateTime(2026, 10, 26, 10));
      expect(
        draft!.endAt.difference(draft!.startAt),
        const Duration(minutes: 60),
        reason: '同日拖选的口径是偏好默认时长，不在本卡改动',
      );
    });
  });

  group('#240 判据', () {
    test('spansMultipleDays', () {
      expect(
        CalendarViewCallbacks.spansMultipleDays(
            DateTime(2026, 10, 26, 23), DateTime(2026, 10, 27, 1)),
        isTrue,
      );
      expect(
        CalendarViewCallbacks.spansMultipleDays(
            DateTime(2026, 10, 26, 1), DateTime(2026, 10, 26, 23)),
        isFalse,
      );
    });

    test('inclusiveAllDayEnd', () {
      expect(
        CalendarViewCallbacks.inclusiveAllDayEnd(DateTime(2026, 10, 28, 10)),
        DateTime(2026, 10, 29),
      );
      expect(
        CalendarViewCallbacks.inclusiveAllDayEnd(DateTime(2026, 10, 28)),
        DateTime(2026, 10, 28),
      );
    });
  });
}

class _NoopRepo implements CalendarRepository {
  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(const []);
  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) => Stream.value(const []);
  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(const CalendarPreference());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
