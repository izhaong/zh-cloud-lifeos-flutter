import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/life_test_app.dart';

/// #645 / 矩阵 I8：「显示已拒绝日程」必须是真开关——默认隐藏我自己拒掉的日程，
/// 打开后出现；别人的拒绝与我无关；未登录（身份取不到）时不静默隐藏。
void main() {
  final from = DateTime.utc(2026, 11, 2);
  final to = DateTime.utc(2026, 11, 9);

  CalendarEvent event({required String id, required String title, List<EventInvitee> invitees = const []}) =>
      CalendarEvent(
        id: id,
        calendarId: 'c1',
        uid: id,
        title: title,
        startAt: DateTime.utc(2026, 11, 4, 9),
        endAt: DateTime.utc(2026, 11, 4, 10),
        timeZone: 'UTC',
        invitees: invitees,
        updatedAt: DateTime.utc(2026, 11, 1),
      );

  final mine = event(
    id: 'e-declined',
    title: '我拒了',
    invitees: const [
      EventInvitee(memberUserId: 'm1', displayName: '我', partstat: PartStat.declined),
    ],
  );
  final theirs = event(
    id: 'e-other',
    title: '别人拒了',
    invitees: const [
      EventInvitee(memberUserId: 'm2', displayName: '同事', partstat: PartStat.declined),
    ],
  );
  final plain = event(id: 'e-plain', title: '未受邀');

  ProviderContainer pump({
    required bool showDeclined,
    required String? memberId,
  }) {
    final repo = _Repo(
      [mine, theirs, plain],
      CalendarPreference(showDeclinedEvents: showDeclined),
    );
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        currentMemberIdProvider.overrideWithValue(memberId),
        sidebarPrefsProvider.overrideWith((ref) => null),
        kalenderEventsControllerProvider.overrideWithValue(
          kalender.DefaultEventsController(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<List<String>> titles(ProviderContainer container) async {
    // `container.read(provider.future)` 会撞在 `preferenceProvider` /
    // `calendarsProvider` 由 loading→data 时把 `occurrencesProvider` 打断重建那一档，
    // 拿到的是被 dispose 的旧流（Bad state: disposed during loading）。改成监听
    // 状态流，只在 AsyncData 时完成——loading 中的 error 是重建噪音，等下一版即可。
    final completer = Completer<List<String>>();
    void settle(AsyncValue<List<CalendarOccurrence>> next) {
      if (completer.isCompleted) return;
      if (next.hasValue) {
        completer.complete(next.requireValue.map((o) => o.title).toList());
      }
    }
    final sub = container.listen<AsyncValue<List<CalendarOccurrence>>>(
      occurrencesProvider((from, to)),
      (_, next) => settle(next),
    );
    addTearDown(sub.close);
    settle(sub.read());
    return completer.future.timeout(const Duration(seconds: 5));
  }

  test('关着（Apple 默认）⇒ 只藏我自己拒的那条', () async {
    final c = pump(showDeclined: false, memberId: 'm1');
    expect(await titles(c), containsAll(['别人拒了', '未受邀']));
    expect(
      await titles(c),
      isNot(contains('我拒了')),
      reason: 'TC-CAL-UI-218：showDeclinedEvents=false 必须真的过滤视图（此前零消费方）',
    );
  });

  test('打开 ⇒ 我自己拒的那条回来', () async {
    final c = pump(showDeclined: true, memberId: 'm1');
    expect(await titles(c), containsAll(['我拒了', '别人拒了', '未受邀']));
  });

  test('未登录（拿不到「我」）⇒ 一条都不藏', () async {
    final c = pump(showDeclined: false, memberId: null);
    expect(
      await titles(c),
      containsAll(['我拒了', '别人拒了', '未受邀']),
      reason: '判不出是不是我拒的就不能静默隐藏（与「日历未加载不闪没」同口径）',
    );
  });

  test('只有我 declined 才算，别人拒了不影响我的视图', () async {
    final c = pump(showDeclined: false, memberId: 'm1');
    expect(await titles(c), contains('别人拒了'));
  });

  testWidgets('设置面有「显示已拒绝日程」开关，点了写回偏好', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final repo = _Repo(const [], const CalendarPreference());
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(
          const Scaffold(body: CalendarSettingsSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('settings_show_declined_events'));
    expect(toggle, findsOneWidget, reason: '此前设置面根本没有这一行，用户打不开该偏好');
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(repo.saved?.showDeclinedEvents, isTrue,
        reason: '开关⇒偏好⇒视图链路必须通（同 #639 的链路断言口径）');
  });
}

class _Repo implements CalendarRepository {
  _Repo(this._events, this._preference);

  final List<CalendarEvent> _events;
  CalendarPreference _preference;
  final _prefs = StreamController<CalendarPreference>.broadcast();

  CalendarPreference? saved;

  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(const [
        Calendar(id: 'c1', title: '个人', colorArgb: 0xFF007AFF),
      ]);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) =>
      Stream.value(List<CalendarEvent>.unmodifiable(_events));

  @override
  Stream<CalendarPreference> watchPreference() async* {
    yield _preference;
    yield* _prefs.stream;
  }

  @override
  Future<void> savePreference(CalendarPreference p) async {
    _preference = p;
    saved = p;
    _prefs.add(p);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
