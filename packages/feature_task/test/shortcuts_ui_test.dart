import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  // 说明：flutter_test 的 simulateKeyDownEvent 不携带修饰键按下状态，
  // 物理组合键（⌘N/⌘F）无法在 widget 测试中端到端模拟——flutter_test
  // 已知限制。此处覆盖：controller 广播链路、空实现兜底、广播驱动 UI、
  // 激活器键位静态核对。真机/桌面手动验收 ⌘N/⌘F。

  // TC-UI-301
  testWidgets('TaskShortcuts controller 广播票据自增', (tester) async {
    late TaskShortcutsController controller;
    await tester.pumpWidget(
      TaskShortcuts(
        child: Builder(
          builder: (context) {
            controller = TaskShortcuts.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    final beforeN = controller.newReminderTicket;
    final beforeF = controller.focusSearchTicket;
    controller.requestNewReminder();
    controller.requestFocusSearch();
    expect(controller.newReminderTicket, beforeN + 1);
    expect(controller.focusSearchTicket, beforeF + 1);
  });

  // TC-UI-301
  testWidgets('未包 TaskShortcuts 时 of() 返回空实现不抛错', (tester) async {
    late TaskShortcutsController controller;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          controller = TaskShortcuts.of(context);
          return const SizedBox();
        },
      ),
    );
    // 空实现：可安全调用、无监听者不崩（票据自增无副作用）
    controller.requestNewReminder();
    controller.requestFocusSearch();
    expect(controller.newReminderTicket, 1);
    expect(controller.focusSearchTicket, 1);
  });

  // TC-UI-301
  testWidgets('快捷键广播驱动 ListContentPane 打开草稿行', (tester) async {
    final repo = InMemoryReminderRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1366, 1024)
      ..devicePixelRatio = 1.0;

    late TaskShortcutsController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: TaskShortcuts(
            child: Builder(
              builder: (context) {
                controller = TaskShortcuts.of(context);
                return const TaskScaffold(openListId: 'list.personal');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 广播「新建提醒」→ 列表内容区打开草稿行（首帧后监听已挂上）
    // #388：起手必须没有草稿行——这条是负对照，缺了它下面的断言就退化成
    // 「常驻搜索框在不在」，广播链路断了也照样绿。
    expect(find.byKey(const ValueKey('draft_row')), findsNothing);
    controller.requestNewReminder();
    await tester.pumpAndSettle();
    // 判据收在草稿行自己的 key 上（原来用 find.byType(CupertinoTextField)，
    // 与常驻的 toolbar_search 同型 ⇒ 恒真，见 #388）。
    expect(find.byKey(const ValueKey('draft_row')), findsOneWidget);

    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  test('激活器键位静态核对：⌘N / ⌘F', () {
    const nActivator = SingleActivator(LogicalKeyboardKey.keyN, meta: true);
    const fActivator = SingleActivator(LogicalKeyboardKey.keyF, meta: true);
    expect(nActivator.trigger, LogicalKeyboardKey.keyN);
    expect(nActivator.meta, isTrue);
    expect(fActivator.trigger, LogicalKeyboardKey.keyF);
    expect(fActivator.meta, isTrue);
  });

  // #388：合成修饰键确实能进 HardwareKeyboard，所以 ⌘N/⌘F 的端到端不必只靠真人走查。
  // 前提是焦点在 Shortcuts 子树里——先点工具栏搜索框把焦点带进来。
  testWidgets('⌘N 合成键端到端打开草稿行，⌘F 再把焦点送回搜索框（#388）', (tester) async {
    final repo = InMemoryReminderRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1366, 1024)
      ..devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: TaskShortcuts(
            child: Builder(
              builder: (context) =>
                  const TaskScaffold(openListId: 'list.personal'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 焦点进子树
    await tester.tap(find.byKey(const ValueKey('toolbar_search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('draft_row')), findsNothing);

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.metaLeft,
      physicalKey: PhysicalKeyboardKey.metaLeft,
    );
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.keyN,
      physicalKey: PhysicalKeyboardKey.keyN,
    );
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.keyN,
      physicalKey: PhysicalKeyboardKey.keyN,
    );
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.metaLeft,
      physicalKey: PhysicalKeyboardKey.metaLeft,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('draft_row')),
      findsOneWidget,
      reason: '⌘N 没被 Shortcuts→Actions 消费：草稿行未出现',
    );

    // ⌘F 之前必须先把焦点挪离搜索框：否则「搜索框有焦点」这条断言
    // 在起手就成立，⌘F 绑定摘掉也照样绿——正是 #388 量的那类恒真判据。
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('draft_row')),
        matching: find.byType(CupertinoTextField),
      ),
    );
    await tester.pumpAndSettle();
    var search = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('toolbar_search')),
    );
    expect(
      search.focusNode?.hasFocus,
      isFalse,
      reason: '起手条件不成立：搜索框仍持焦，⌘F 断言会恒真',
    );

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.metaLeft,
      physicalKey: PhysicalKeyboardKey.metaLeft,
    );
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.keyF,
      physicalKey: PhysicalKeyboardKey.keyF,
    );
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.keyF,
      physicalKey: PhysicalKeyboardKey.keyF,
    );
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.metaLeft,
      physicalKey: PhysicalKeyboardKey.metaLeft,
    );
    await tester.pumpAndSettle();
    search = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('toolbar_search')),
    );
    expect(
      search.focusNode?.hasFocus,
      isTrue,
      reason: '⌘F 没把焦点送进搜索框（requestFocusSearch 链路断）',
    );

    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
}
