// TC-CAL-UI-512 / TC-CAL-UI-513：快捷键的**行为**（不只是绑定映射）。
//
// 由来（#357）：矩阵 A10（⌘R 刷新）与 I2（⌘←/→ 翻页、⌘T 今天、⇧⌘T 跳日期）
// 裁「对等」，但用例列写的是「待补：5xx 系列」。查证发现实现与绑定都在
// （`calendar_shortcuts.dart`、`search_shortcuts_test.dart:139` 断言了映射），
// 缺的是「按下去到底做了什么」的测试。
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {required Widget child}) async {
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFFFFFFFF),
      builder: (context, _) => child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TC-CAL-UI-512 ⌘R 触发 onRefresh 一次', (tester) async {
    var refreshes = 0;
    await _pump(
      tester,
      child: CalendarShortcutActions(
        onRefresh: () => refreshes++,
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(refreshes, 1, reason: '⌘R 必须真的触发刷新回调，而不只是绑定表里有这一项');
  });

  testWidgets('TC-CAL-UI-513 ⌘→/⌘← 翻页、⌘T 回今天', (tester) async {
    var next = 0;
    var prev = 0;
    var today = 0;
    await _pump(
      tester,
      child: CalendarShortcutActions(
        onNextPeriod: () => next++,
        onPrevPeriod: () => prev++,
        onToday: () => today++,
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(next, 1, reason: '⌘→ 应推进一个周期');
    expect(prev, 1, reason: '⌘← 应回退一个周期');
    expect(today, 1, reason: '⌘T 应回到今天');
  });

  testWidgets('对照：不按修饰键的 → 不触发翻页（防误触）', (tester) async {
    var next = 0;
    await _pump(
      tester,
      child: CalendarShortcutActions(
        onNextPeriod: () => next++,
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(next, 0);
  });
}
