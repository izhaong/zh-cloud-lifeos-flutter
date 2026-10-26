import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;

/// F-12 快速事件输入框（TC-CAL-UI-170；契约 §6）。
void main() {
  final now = DateTime.utc(2026, 10, 24, 9);

  testWidgets('TC-CAL-UI-170 明天下午3点开会', (tester) async {
    QuickEvent? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showQuickEventDialog(context,
                  now: now, timeZone: 'UTC');
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('quick_event_input')), '明天下午3点开会');
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick_event_create')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.title, '开会');
    expect(result!.startAt, DateTime.utc(2026, 10, 25, 15));
    expect(result!.endAt, DateTime.utc(2026, 10, 25, 16));
  });

  testWidgets('工具栏「＋」打开同一个输入框 → 创建后进入 Inspector', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _Repo();
    final controller = kalender.DefaultEventsController();
    final container = ProviderContainer(overrides: [
      calendarRepositoryProvider.overrideWithValue(repo),
      sidebarPrefsProvider.overrideWith((ref) => null),
      kalenderEventsControllerProvider.overrideWithValue(controller),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CalendarScaffold()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新建日程').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick_event_dialog')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('quick_event_input')), '明天下午3点开会');
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick_event_create')));
    await tester.pumpAndSettle();

    // compact → 全屏 Inspector，标题字段带解析结果
    expect(find.byKey(const Key('event_inspector_pane')), findsOneWidget);
    final field = tester.widget<TextField>(
        find.byKey(const Key('event_field_title')));
    expect(field.controller!.text, '开会');
  });
}

class _Repo implements CalendarRepository {
  final List<Calendar> calendars = [const Calendar(
      id: 'c1', title: '工作', colorArgb: 0xFF007AFF, isDefault: true)];
  final _events = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<CalendarEvent>> watchEvents(
          {required DateTime from,
          required DateTime to,
          Set<String>? calendarIds}) async* {
    yield const <CalendarEvent>[];
    yield* _events.stream;
  }

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield calendars;
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
    yield* const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
