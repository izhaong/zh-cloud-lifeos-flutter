import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'support/life_test_app.dart';

/// Issue #1 线框三端链路收口审计 · 占位链路测试
/// 覆盖：TC-UI-207（手机 ⋯编辑占位）、TC-UI-306（设置弹层）。
Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required ReminderRepository repo,
  Widget child = const TaskScaffold(),
}) async {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: lifeTestHost(child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  // TC-UI-207：首页 ⋯ → 编辑占位（规划），显示反馈且不崩溃
  testWidgets('TC-UI-207 手机首页 ⋯打开列表编辑框且可返回（#491）', (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(tester, size: const Size(375, 812), repo: repo);

    expect(find.byKey(const ValueKey('home_edit_placeholder')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home_edit_placeholder')));
    await tester.pumpAndSettle();

    final pick = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('edit_pick_'),
    );
    if (pick.evaluate().isNotEmpty) {
      await tester.tap(pick.first);
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('edit_list_name')), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('我的列表'), findsOneWidget);
  });

  // TC-UI-306：客户端 ⚙设置 → 弹层出现（**三行规划占位**，非图1 全字段；
  // 图1 的默认列表/全天/标记/建议/还原表单属 TC-UI-120，M1 服务端核对后实现）
  testWidgets('TC-UI-306 设置弹层：图1 字段真身出现且可关闭（实机差距批升级）',
      (tester) async {
    final repo = InMemoryReminderRepository();
    // 宽屏走 _ThreePane：侧栏有设置入口
    await _pump(
      tester,
      size: const Size(1366, 1024),
      repo: repo,
      child: const TaskScaffold(openListId: 'smart.today'),
    );

    await tester.tap(find.byKey(const ValueKey('sidebar_settings')));
    await tester.pumpAndSettle();

    // 图1 级真身（TC-UI-120 骨架）：默认列表/全天提醒时点/标记完成/建议列表/还原
    expect(find.text('设置'), findsWidgets);
    expect(find.text('默认列表'), findsOneWidget);
    expect(find.text('全天提醒时点'), findsOneWidget);
    expect(find.text('完成时标记为已完成'), findsOneWidget);
    expect(find.text('建议列表'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings_reset')), findsOneWidget);

    // #444：「采购清单语言」原先是无 onTap、不落库、无消费者的硬编码占位，
    // 按「要么补消费者、要么不摆成可设置的样子」撤除。这里留一条反向断言：
    // 撤的是整行（含键），而有效四档仍在——否则「字段真身出现」会静默失真。
    expect(find.text('采购清单语言'), findsNothing);
    expect(
      find.byKey(const ValueKey('settings_grocery_language')),
      findsNothing,
    );
    expect(find.text('简体中文'), findsNothing);

    // 开关可交互（切换不炸）
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();

    // 关闭：点导航栏「完成」
    await tester.tap(find.byKey(const ValueKey('settings_done')));
    await tester.pumpAndSettle();
    expect(find.text('默认列表'), findsNothing);
  });
}
