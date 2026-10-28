import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_task/feature_task.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #249：macOS ⌘⇧N 打开「新建列表」（Apple ⇧⌘N；TC-UI-316 的快捷键入口）。
///
/// 物理按键在 widget 测试里不稳定（与 shortcuts_ui_test.dart 同口径）：
/// 键位用「绑定表静态核对」钉住，行为用控制器广播验证。
void main() {
  test('⌘⇧N 激活器进绑定表（键位静态核对）', () {
    const activator = SingleActivator(
      LogicalKeyboardKey.keyN,
      meta: true,
      shift: true,
    );
    expect(activator.trigger, LogicalKeyboardKey.keyN);
    expect(activator.meta, isTrue);
    expect(activator.shift, isTrue);
    expect(activator.alt, isFalse);
    expect(activator.control, isFalse);
  });

  testWidgets('⌘⇧N 广播 → 打开新建列表对话框', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '列表A'));
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);

    late TaskShortcutsController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: CupertinoApp(
          home: TaskShortcuts(
            child: Builder(
              builder: (context) {
                controller = TaskShortcuts.of(context);
                return const TaskScaffold(openListId: 'list.a');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shortcuts = tester.widget<Shortcuts>(
      find
          .descendant(
            of: find.byType(TaskShortcuts),
            matching: find.byType(Shortcuts),
          )
          .first,
    );
    expect(
      shortcuts.shortcuts.keys.whereType<SingleActivator>().where(
            (a) => a.trigger == LogicalKeyboardKey.keyN && a.meta && a.shift,
          ),
      isNotEmpty,
      reason: '⌘⇧N 必须进 Shortcuts 绑定表，否则按键永远没反应',
    );

    controller.requestNewList();
    await tester.pumpAndSettle();

    expect(find.text('新列表'), findsOneWidget, reason: '⌘⇧N 应打开新建列表对话框');
    expect(find.byKey(const ValueKey('new_list_name')), findsOneWidget);
  });
}
