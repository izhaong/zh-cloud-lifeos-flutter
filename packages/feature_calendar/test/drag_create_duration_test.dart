import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// #294：时间轴拖拽创建时，事件长度 = 拖出来的长度；双击才回落默认时长。
void main() {
  CalendarViewCallbacks callbacks({int defaultMinutes = 60}) =>
      CalendarViewCallbacks(
        repo: _NullRepo(),
        preference: CalendarPreference(defaultDurationMinutes: defaultMinutes),
        setDraft: (_) {},
      );

  test('拖 10:00 → 12:00 得到两小时（不再恒为默认 60 分钟）', () {
    final c = callbacks();
    final draft = c.onDraftCreate(
      DateTime(2026, 10, 28, 10),
      DateTime(2026, 10, 28, 12),
    );
    expect(draft.startAt.toLocal().hour, 10);
    expect(
      draft.endAt.toLocal().difference(draft.startAt.toLocal()),
      const Duration(hours: 2),
    );
  });

  test('双击（start == end）仍用偏好默认时长（TC-CAL-UI-130 口径不变）', () {
    final c = callbacks(defaultMinutes: 30);
    final at = DateTime(2026, 10, 28, 10);
    final draft = c.onDraftCreate(at, at);
    expect(
      draft.endAt.toLocal().difference(draft.startAt.toLocal()),
      const Duration(minutes: 30),
    );
  });

  test('倒拖（end 早于 start）不产生负时长，回落默认', () {
    final c = callbacks(defaultMinutes: 45);
    final draft = c.onDraftCreate(
      DateTime(2026, 10, 28, 12),
      DateTime(2026, 10, 28, 10),
    );
    expect(
      draft.endAt.toLocal().difference(draft.startAt.toLocal()),
      const Duration(minutes: 45),
    );
  });
}

class _NullRepo implements CalendarRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
