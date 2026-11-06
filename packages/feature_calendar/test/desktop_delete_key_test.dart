import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// #653 / 矩阵 D16 桌面 Delete 键 ⇒ 触发 `onDeleteSelected`。
///
/// 此前只断过绑定表（`search_shortcuts_test.dart`）里有
/// `SingleActivator(delete) ⇒ DeleteSelectedIntent` 这一项；
/// 但**按下去是否真的把回调打出去**没跑过——这条与
/// `TC-CAL-UI-512/513`（⌘R / ⌘←→ 行为断言）同族，把 Delete 补齐。

/// 结构（与 `calendar_scaffold.dart` 一致，两层各管一边）：
/// - 外层 `CalendarShortcutActions`（:398）：`Actions` 表 + ⌘ 组合键；
/// - 内层 `Shortcuts(calendarUnmodifiedShortcutBindings())`（:497）：裸键表，
///   后面紧跟 `Focus(autofocus: true)`——焦点必须落在这层**之内**。
/// Delete 的「绑定」在内层、「动作」在外层 ⇒ 少套任意一层都打不到回调。
Widget host({VoidCallback? onDeleteSelected}) => CalendarShortcutActions(
  onDeleteSelected: onDeleteSelected,
  child: Shortcuts(
    shortcuts: calendarUnmodifiedShortcutBindings(),
    child: const Focus(autofocus: true, child: SizedBox.expand()),
  ),
);

void main() {
  Future<void> pump(WidgetTester tester, {required Widget child}) async {
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFFFFFFFF),
        builder: (context, _) => child,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('TC-CAL-UI-223 桌面 Delete 键真的触发 onDeleteSelected', (tester) async {
    var deletes = 0;
    await pump(tester, child: host(onDeleteSelected: () => deletes++));

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(
      deletes,
      1,
      reason:
          '按 Delete 应把 DeleteSelectedIntent 落到 CallbackAction ⇒ onDeleteSelected 计数 +1',
    );
  });

  testWidgets('对照：未注入 onDeleteSelected ⇒ 按 Delete 不抛、不回调', (tester) async {
    await pump(tester, child: host());
    // 空回调时按 Delete：CallbackAction 里 `onDeleteSelected?.call()` 是安全 no-op，
    // 不应抛；这条挡住「摘成必抛」那种坏变异，与 TC-CAL-UI-512/513 同口径。
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '未注入回调时 Delete 应静默 no-op');
  });
}
