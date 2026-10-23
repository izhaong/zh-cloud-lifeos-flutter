import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      child: MaterialApp(home: child),
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
  testWidgets('TC-UI-207 手机首页 ⋯编辑占位：提示且不崩溃', (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(tester, size: const Size(375, 812), repo: repo);

    expect(find.byKey(const ValueKey('home_edit_placeholder')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home_edit_placeholder')));
    await tester.pumpAndSettle();

    // 占位反馈出现（SnackBar「规划」），界面不崩溃、首页仍在
    expect(find.textContaining('规划'), findsWidgets);
    expect(find.text('我的列表'), findsOneWidget);
  });

  // TC-UI-306：客户端 ⚙设置 → 弹层出现（**三行规划占位**，非图1 全字段；
  // 图1 的默认列表/全天/标记/建议/还原表单属 TC-UI-120，M1 服务端核对后实现）
  testWidgets('TC-UI-306 设置弹层：三行规划占位出现且可关闭（非图1 全字段）',
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

    // 弹层出现：标题「设置」+ 三行规划占位（账号同步占位/通知 P1/外观跟随系统）
    expect(find.text('设置'), findsWidgets);
    expect(find.text('账号与同步'), findsOneWidget);
    expect(find.text('通知与提醒'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);

    // 关闭：点 sheet 外
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    expect(find.text('账号与同步'), findsNothing);
  });
}
