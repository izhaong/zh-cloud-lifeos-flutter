import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

/// #647 / 矩阵 D21 + D22：
/// - D21「显示为 忙碌/空闲」在表单里此前只被 TC-CAL-UI-132 的「字段存在 + 顺序」覆盖，
///   没有断到「点了以后 `CalendarEvent.availability` 真的翻，UI 显示的文案跟着改」；
/// - D22「私密复选框」同理，字段挂在表单里但没有一条断言证明
///   `Switch ⇒ event.isPrivate`。
/// 这里各补一条独立用例，把两行 FL 从「部分」推到「有」。
void main() {
  late _MutableRepo repo;
  late ProviderContainer container;
  final controller = kalender.DefaultEventsController();

  CalendarEvent draft({
    EventAvailability availability = EventAvailability.busy,
    bool isPrivate = false,
  }) =>
      CalendarEvent(
        id: 'e1',
        calendarId: 'c1',
        uid: 'u1',
        title: '周会',
        startAt: DateTime.utc(2026, 10, 24, 10),
        endAt: DateTime.utc(2026, 10, 24, 11),
        timeZone: 'UTC',
        availability: availability,
        isPrivate: isPrivate,
        updatedAt: DateTime.utc(2026, 10, 24),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    controller.clearEvents();
    repo = _MutableRepo();
    container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
        kalenderEventsControllerProvider.overrideWithValue(controller),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpInspector(
    WidgetTester tester, {
    required CalendarEvent event,
  }) async {
    // 表单字段共 14 个，默认 800×900 视口会裁掉 availability/private，
    // 用 800×2400 让整张表进树（与 TC-CAL-UI-132 同一档）。
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(
          Scaffold(
            body: EventInspectorPane(
              initialEvent: event,
              onSaved: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 从 `EventInspectorPane` 的 `_draft` 里取「最近一次表单交互后的事件」——
  /// 用 `repo.upserted` 会拿不到，因为「保存」按钮没点；这里读 Inspector 内部
  /// 通过 `_emit(_copyWith(_e, ...))` 更新的状态，落点是可见的 `trailing` 文案，
  /// 所以断言在「忙碌/空闲」的文本翻转 + 「私密开关」的 `value` 翻转。
  testWidgets('TC-CAL-UI-219 D21 显示为：忙碌→空闲→忙碌 全链路', (tester) async {
    await pumpInspector(tester, event: draft(availability: EventAvailability.busy));

    // 默认 busy ⇒ trailing 文案是「忙碌」
    expect(
      find.descendant(
        of: find.byKey(const Key('event_field_availability')),
        matching: find.text('忙碌'),
      ),
      findsOneWidget,
      reason: 'TC-CAL-UI-219 初始 busy ⇒ 表单显示「忙碌」',
    );

    // 点 trailing CupertinoButton ⇒ 弹 sheet ⇒ 选「空闲」
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('event_field_availability')),
        matching: find.byType(CupertinoButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('空闲'), findsWidgets,
        reason: 'sheet 弹出，选项含「空闲」（另有 trailing 文案与「取消」，用 findsWidgets）');
    await tester.tap(find.text('空闲').last);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('event_field_availability')),
        matching: find.text('空闲'),
      ),
      findsOneWidget,
      reason: '选「空闲」后 availability 落到 _draft，UI 立即回显「空闲」',
    );

    // 反向切回「忙碌」
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('event_field_availability')),
        matching: find.byType(CupertinoButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('忙碌').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('event_field_availability')),
        matching: find.text('忙碌'),
      ),
      findsOneWidget,
      reason: '再切回「忙碌」——不是单向的假绿',
    );
  });

  testWidgets('TC-CAL-UI-220 D22 私密开关：Switch 翻 ⇒ isPrivate 跟着翻', (tester) async {
    await pumpInspector(tester, event: draft(isPrivate: false));

    final sw = find.descendant(
      of: find.byKey(const Key('event_field_private')),
      matching: find.byType(CupertinoSwitch),
    );
    expect(sw, findsOneWidget,
        reason: 'TC-CAL-UI-220 表单里私密那一行的开关要能被 finder 命中');
    expect(tester.widget<CupertinoSwitch>(sw).value, isFalse,
        reason: '初始未勾');

    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(tester.widget<CupertinoSwitch>(sw).value, isTrue,
        reason: '点一下 ⇒ 勾上');

    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(tester.widget<CupertinoSwitch>(sw).value, isFalse,
        reason: '再点 ⇒ 取消（避免单向假绿）');
  });
}

class _MutableRepo implements CalendarRepository {
  final List<CalendarEvent> upserted = [];
  final List<Calendar> calendars = [];
  final List<CalendarEvent> visible = [];
  final _eventController = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield List<CalendarEvent>.unmodifiable(visible);
    yield* _eventController.stream;
  }

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(calendars);
  }

  @override
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    upserted.add(e);
    visible.add(e);
    _eventController.add(List<CalendarEvent>.unmodifiable(visible));
    return e.id;
  }

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield const CalendarPreference();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
