// TC-CAL-UI-514 / TC-CAL-UI-515：侧栏修饰键快速显隐（Apple C-133）。
//
// 由来（#360）：矩阵 A7 裁「对等」，但 ⌘点全选（allVisible）与 ⌥⌘点仅此（onlyId）
// 在 UI 上**按不出来**——仓储 API 早就备好，lib 里却没有修饰键检测。
// 本测试驱动**真实侧栏**（不是直接调 repo），断言「按下去发生了什么」。
import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录调用形状的假仓储。
class _RecordingRepo implements CalendarRepository {
  final List<Calendar> calendars = [];
  final List<String> calls = [];
  final _c = StreamController<List<Calendar>>.broadcast();

  @override
  Future<void> setVisibility({
    String? id,
    bool? visible,
    bool? allVisible,
    String? onlyId,
  }) async {
    if (allVisible != null) {
      calls.add('allVisible=$allVisible');
    } else if (onlyId != null) {
      calls.add('onlyId=$onlyId');
    } else {
      calls.add('id=$id,visible=$visible');
    }
  }

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(calendars);
    yield* _c.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_RecordingRepo> _pumpSidebar(WidgetTester tester) async {
  final repo = _RecordingRepo()
    ..calendars.addAll(const [
      Calendar(id: 'a', title: '工作', colorArgb: 0xFF007AFF, isVisible: true),
      Calendar(id: 'b', title: '生活', colorArgb: 0xFF34C759, isVisible: true),
    ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
      ],
      child: const MaterialApp(home: Scaffold(body: CalendarSidebar())),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _tapWithMeta(WidgetTester tester, Finder finder,
    {bool alt = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TC-CAL-UI-514 ⌘点：全部显隐（allVisible）', (tester) async {
    final repo = await _pumpSidebar(tester);
    await _tapWithMeta(tester, find.byKey(const Key('cal-visibility-a')));

    expect(repo.calls, ['allVisible=false'],
        reason: '⌘点应一次把全部日历切到与本条相反的状态');
  });

  testWidgets('TC-CAL-UI-515 ⌥⌘点：只留这一本（onlyId）', (tester) async {
    final repo = await _pumpSidebar(tester);
    await _tapWithMeta(tester, find.byKey(const Key('cal-visibility-b')),
        alt: true);

    expect(repo.calls, ['onlyId=b'],
        reason: '⌥⌘点只应保留被点的那一本');
  });

  testWidgets('TC-CAL-UI-516 侧栏空格切换焦点行显隐（行为，不只是绑定）', (tester) async {
    final repo = await _pumpSidebar(tester);

    // 让第一本日历行获得焦点（row 上是 Focus，Tab 会走进去）。
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(repo.calls, isNotEmpty,
        reason: '侧栏里按空格必须真的切显隐；此前只挂了 Shortcuts、没有 Actions，等于空操作');
    expect(repo.calls.first, startsWith('id='));
  });

  testWidgets('对照组：无修饰键只切单条', (tester) async {
    final repo = await _pumpSidebar(tester);
    await tester.tap(find.byKey(const Key('cal-visibility-a')));
    await tester.pumpAndSettle();

    expect(repo.calls, ['id=a,visible=false'],
        reason: '无修饰键不应影响其他日历');
  });
}
