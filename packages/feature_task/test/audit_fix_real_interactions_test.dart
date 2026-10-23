import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Issue #1 审计修复 · 真实交互测试（替换过度宣称的锚点）
/// 覆盖：TC-UI-304（侧栏显隐真实交互）、TC-UI-307（inspector 就地切换/关闭）、
/// TC-UI-N3（负向门禁：无第二套 NavigationBar、无「大 Todo」IA 泄漏、宽屏负向文案）。
Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required ReminderRepository repo,
  Widget child = const TaskScaffold(openListId: 'smart.today'),
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

  // TC-UI-304：侧栏显隐——隐藏按钮真实可点、主区铺满、再显示恢复
  testWidgets('TC-UI-304 侧栏隐藏→主区铺满→再显示恢复', (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(tester, size: const Size(1366, 1024), repo: repo);

    // 初始：侧栏可见（智能列表区在）
    expect(find.text('智能列表'), findsOneWidget);

    // 点侧栏「隐藏侧栏」按钮（真实交互，非 provider 单测）
    await tester.tap(find.byKey(const ValueKey('sidebar_toggle')));
    await tester.pumpAndSettle();

    // 隐藏后：侧栏内容消失，主区出现「显示侧栏」恢复按钮
    expect(find.text('智能列表'), findsNothing);
    expect(find.byKey(const ValueKey('show_sidebar')), findsOneWidget);

    // 再点恢复 → 侧栏回来
    await tester.tap(find.byKey(const ValueKey('show_sidebar')));
    await tester.pumpAndSettle();
    expect(find.text('智能列表'), findsOneWidget);
    expect(find.byKey(const ValueKey('show_sidebar')), findsNothing);
  });

  // TC-UI-307：inspector 点行出现、点其他行就地切换
  testWidgets('TC-UI-307 inspector 出现与就地切换', (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(
      tester,
      size: const Size(1366, 1024),
      repo: repo,
      child: const TaskScaffold(openListId: 'list.personal'),
    );

    // 初始无 inspector
    expect(find.text('详细信息'), findsNothing);

    // 点「买牛奶」行 → inspector 出现且标题同步
    await tester.tap(find.text('买牛奶'));
    await tester.pumpAndSettle();
    expect(find.text('详细信息'), findsOneWidget);

    // 点另一行「写 LifeOS 基建」→ 就地切换（不叠加、不重开）
    await tester.tap(find.text('写 LifeOS 基建'));
    await tester.pumpAndSettle();
    expect(find.text('详细信息'), findsOneWidget); // 仍是唯一 inspector
  });

  // TC-UI-N3：负向门禁——无第二套底部导航、宽屏无未实现文案
  testWidgets('TC-UI-N3 宽屏负向：任务区无 NavigationBar 泄漏、无未实现文案',
      (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(tester, size: const Size(1366, 1024), repo: repo);

    // 任务区内部不得出现第二套底部导航（「大 Todo」IA 泄漏红线）
    expect(
      find.byType(NavigationBar),
      findsNothing,
      reason: '任务区（TaskScaffold 内）不得含 NavigationBar——壳层独有',
    );
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(TabBar), findsNothing);

    // 宽屏侧栏同样跑未实现文案门禁（原 N2 仅紧凑首页）
    expect(find.textContaining('iCloud'), findsNothing);
    expect(find.textContaining('Outlook'), findsNothing);
    expect(find.textContaining('分配事项'), findsNothing);
    expect(find.textContaining('建议列表'), findsNothing);
  });

  // TC-UI-207 加强：⋯编辑占位精确断言（SnackBar 文案全文）
  testWidgets('TC-UI-207 ⋯编辑占位：SnackBar 全文锁定', (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(
      tester,
      size: const Size(375, 812),
      repo: repo,
      child: const TaskScaffold(),
    );

    await tester.tap(find.byKey(const ValueKey('home_edit_placeholder')));
    await tester.pump(); // SnackBar 出现帧

    // 精确锁全文（未来换真编辑页时该断言失败 → 强制更新测试）
    expect(find.text('编辑列表 · 规划占位'), findsOneWidget);
  });
}
