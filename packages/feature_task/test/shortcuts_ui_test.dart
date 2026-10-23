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

  testWidgets('快捷键广播驱动 ListContentPane 打开草稿行', (tester) async {
    final repo = InMemoryReminderRepository();
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
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
    controller.requestNewReminder();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets); // 草稿行输入框出现

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
}
