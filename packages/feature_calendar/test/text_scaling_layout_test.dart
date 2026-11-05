// TC-CAL-REG-006：大字号（辅助功能「更大的文字」）下四个断点不得溢出。
//
// 渲染期溢出在 widget test 里会直接抛异常 → 「测试绿」就是判据。
// 由来（#351）：375 + textScaler 2.0 时紧凑档工具栏横向溢出 102px
// （标题 Text 无界 + 上一页/今天/下一页/菜单/搜索/新建挤在一行）。
import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;

class _Repo implements CalendarRepository {
  final List<Calendar> calendars = [];
  final List<CalendarEvent> events = [];
  final _c = StreamController<List<Calendar>>.broadcast();
  final _e = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(calendars);
    yield* _c.stream;
  }

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield List<CalendarEvent>.unmodifiable(events);
    yield* _e.stream;
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
    yield* const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const sizes = <String, Size>{
    '375': Size(375, 812),
    '834': Size(834, 1112),
    '1280': Size(1280, 800),
  };
  const scales = <double>[1.0, 2.0];

  for (final entry in sizes.entries) {
    for (final scale in scales) {
      testWidgets('月视图 ${entry.key} 宽 × 字号 $scale 不溢出', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = _Repo()
          ..calendars.add(const Calendar(
            id: 'c1',
            title: '工作',
            colorArgb: 0xFF007AFF,
            isDefault: true,
          ));
        final container = ProviderContainer(
          overrides: [
            calendarRepositoryProvider.overrideWithValue(repo),
            sidebarPrefsProvider.overrideWith((ref) => null),
            kalenderEventsControllerProvider
                .overrideWithValue(kalender.DefaultEventsController()),
          ],
        );
        addTearDown(container.dispose);
        container
            .read(anchorDateProvider.notifier)
            .set(DateTime.utc(2026, 10, 26));

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const MaterialApp(
                home: CalendarScaffold(pinnedViewMode: CalendarViewMode.month),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('calendar_toolbar')), findsOneWidget);
      });
    }
  }
}
