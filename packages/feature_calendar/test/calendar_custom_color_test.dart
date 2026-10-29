// TC-CAL-UI-120/121 补强（#404）：日历颜色不止内置色板。
import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/life_test_app.dart';

class _Repo implements CalendarRepository {
  final List<Calendar> list = [];
  final _c = StreamController<List<Calendar>>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(list);
    yield* _c.stream;
  }

  @override
  Future<void> upsertCalendar(Calendar c) async {
    final i = list.indexWhere((e) => e.id == c.id);
    if (i >= 0) {
      list[i] = c;
    } else {
      list.add(c);
    }
    _c.add(List<Calendar>.unmodifiable(list));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Repo> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _Repo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWithValue(prefs),
      ],
      child: lifeTestHost(const Scaffold(body: CalendarSidebar())),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _openAddDialog(WidgetTester tester) async {
  final target = find.text('添加日历');
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('calendar_sidebar')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  group('parseHexColor（纯函数）', () {
    test('#404 接受 #RRGGBB / RRGGBB，自动补不透明', () {
      expect(parseHexColor('#123456'), 0xFF123456);
      expect(parseHexColor('123456'), 0xFF123456);
      expect(parseHexColor('  #ABCDEF  '), 0xFFABCDEF);
    });

    test('#404 接受 #AARRGGBB；全透明按不透明处理', () {
      expect(parseHexColor('#80123456'), 0x80123456);
      expect(parseHexColor('#00123456'), 0xFF123456,
          reason: '全透明等于看不见，日历颜色不接受');
    });

    test('#404 非法输入返回 null（不抛）', () {
      expect(parseHexColor(''), isNull);
      expect(parseHexColor('#12'), isNull);
      expect(parseHexColor('zzzzzz'), isNull);
      expect(parseHexColor('#1234567'), isNull);
    });

    test('#404 toHexColor 往返', () {
      expect(toHexColor(0xFF123456), '#123456');
      expect(parseHexColor(toHexColor(0xFF0A0B0C)), 0xFF0A0B0C);
    });
  });

  testWidgets('#404 新建日历时可自定义颜色（#RRGGBB 落库）', (tester) async {
    final repo = await _pump(tester);
    await _openAddDialog(tester);

    await tester.tap(find.byKey(const Key('preset-color-custom')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('custom-color-hex')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('calendar_title_field')),
      '自选色',
    );
    await tester.enterText(
      find.byKey(const Key('custom-color-hex')),
      '#123456',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dialog-done')));
    await tester.pumpAndSettle();

    expect(repo.list.single.colorArgb, 0xFF123456,
        reason: '自定义颜色必须真的落库，而不是被内置色板覆盖');
  });

  testWidgets('#404 非法十六进制不改变当前颜色（半输入态不打断）', (tester) async {
    final repo = await _pump(tester);
    await _openAddDialog(tester);

    await tester.tap(find.byKey(const Key('preset-color-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar_title_field')),
      '半输入',
    );
    await tester.enterText(find.byKey(const Key('custom-color-hex')), '#12');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dialog-done')));
    await tester.pumpAndSettle();

    // 仍是默认蓝（非法输入不该把颜色写成 0/黑）
    expect(repo.list.single.colorArgb, kCalendarPresetColors[4].$2);
  });
}
