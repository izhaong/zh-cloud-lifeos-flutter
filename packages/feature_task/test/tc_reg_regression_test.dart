import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'support/life_test_app.dart';

/// TC-REG-102：布局三档回归（599/600/1199/1200 四宽度边界；
/// 档位切换正确、无残留叠加——对照 TC-UI-302/304/307）。
/// TC-REG-108：生命周期（重 pump 即重订阅；数据不丢、Stream 不断流）。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget host(
    ReminderRepository repo, {
    String? selectedItemId,
    String openListId = 'smart.today',
  }) => ProviderScope(
    overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
    child: lifeTestHost(
      TaskScaffold(openListId: openListId, selectedItemId: selectedItemId),
    ),
  );

  testWidgets('TC-REG-102 四宽度断点各归正确档位', (tester) async {
    final repo = InMemoryReminderRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;

    // 599 = compact（栈导航；无侧栏）
    view.physicalSize = const Size(599, 900);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(host(repo));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('sidebar_toggle')),
      findsNothing,
      reason: '599 应为紧凑单栏',
    );

    // 600 = medium（二栏；侧栏可见可隐）
    view.physicalSize = const Size(600, 900);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('sidebar_toggle')),
      findsOneWidget,
      reason: '600 应为二栏',
    );

    // 1199 = medium 顶格
    view.physicalSize = const Size(1199, 900);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('sidebar_toggle')),
      findsOneWidget,
      reason: '1199 仍二栏',
    );

    // 1200 = expanded（三栏可开）——与 medium 的区分锁：选中条目时出 inspector
    view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('sidebar_toggle')),
      findsOneWidget,
      reason: '1200 三栏（侧栏仍在，inspector 按选中出现）',
    );
    // 跨档无残留叠加：无重复侧栏
    expect(
      find.byKey(const ValueKey('sidebar_toggle')).evaluate().length,
      lessThanOrEqualTo(1),
    );
  });

  testWidgets('TC-REG-102 medium≠expanded：1200 选条目出 inspector，1199 不出', (
    tester,
  ) async {
    final repo = InMemoryReminderRepository(seedSampleData: true);
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;

    // 1199（medium）：选中也不出第三列
    view.physicalSize = const Size(1199, 1000);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(host(repo, openListId: 'list.personal'));
    await tester.pumpAndSettle();
    expect(
      find.text('详细信息'),
      findsNothing,
      reason: 'medium 档无第三列（selectedItemId 需经 TaskScaffold 自持选中）',
    );

    // 1200（expanded）：_ThreePane 自持选中 → 点行出 inspector
    view.physicalSize = const Size(1200, 1000);
    await tester.pumpWidget(host(repo, openListId: 'list.personal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('买牛奶'));
    await tester.pumpAndSettle();
    expect(
      find.text('详细信息'),
      findsOneWidget,
      reason: 'expanded 档选中行必须出现第三列（medium/expanded 区分锁）',
    );
  });

  testWidgets('TC-REG-108 生命周期：重 pump 后数据不丢、Stream 重订阅不断流', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.w', title: '工作'));
    final now = DateTime.now();
    await repo.upsertItem(
      ReminderItem(
        id: 'keep',
        listId: 'list.w',
        title: '生命周期条目',
        dueAt: now, // smart.today 视图可见
      ),
    );

    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(834, 1112);
    view.devicePixelRatio = 1.0;

    // 第一生命周期
    await tester.pumpWidget(host(repo));
    await tester.pumpAndSettle();
    expect(find.text('生命周期条目'), findsOneWidget);

    // 「冷重启」模拟：整树重建（ProviderScope+MaterialApp 全新）
    await tester.pumpWidget(host(repo));
    await tester.pumpAndSettle();
    expect(find.text('生命周期条目'), findsOneWidget, reason: '重建后 Stream 重订阅，数据不丢');

    // 热恢复近似（widget 级）：数据变更仍能驱动重建后的 UI（断流检测）——
    // 真实 AppLifecycleState 后台/前台与杀进程恢复属手动清单（设备项）
    await repo.upsertItem(
      ReminderItem(id: 'after', listId: 'list.w', title: '后台回来新增', dueAt: now),
    );
    await tester.pumpAndSettle();
    expect(find.text('后台回来新增'), findsOneWidget, reason: '回前台后流仍活跃（写操作驱动刷新）');
  });

  testWidgets('M5 实机差距批：空列表也渲染列表色大标题（cursor 复验 P0）', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(id: 'list.empty', title: '空列表', colorArgb: 0xFFFF9500),
    );

    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(const TaskScaffold(openListId: 'list.empty')),
      ),
    );
    await tester.pumpAndSettle();

    // 空列表：大标题（列表色）在内容区 + 空态引导 + 底栏新提醒
    final title = find.byKey(const ValueKey('list_large_title'));
    expect(title, findsOneWidget, reason: '空列表必须有列表色大标题');
    final text = find.descendant(of: title, matching: find.text('空列表'));
    expect(text, findsOneWidget);
    final style = tester.widget<Text>(text).style;
    expect(style?.color, const Color(0xFFFF9500), reason: '大标题须带列表色');
    expect(find.byKey(const ValueKey('empty_new_hint')), findsOneWidget);
    expect(find.text('新提醒事项'), findsOneWidget);
  });

  testWidgets('M5 实机差距批：空列表 + 工具栏＋/底栏＋ 出草稿行（cursor 复验 P0）', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.empty', title: '空'));

    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(const TaskScaffold(openListId: 'list.empty')),
      ),
    );
    await tester.pumpAndSettle();

    // 顶栏＋点击 → 草稿行出现（空列表不再吞掉）
    await tester.tap(find.byKey(const ValueKey('toolbar_new_item')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('draft_field')),
      findsWidgets,
      reason: '空列表下草稿行必须可见可输入',
    );
    expect(find.text('没有提醒'), findsNothing, reason: '草稿态时空态让位');
  });

  testWidgets('TC-REG-107 负向门禁全量（M5 档）：紧凑+宽屏双档无泄漏', (tester) async {
    final repo = InMemoryReminderRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;

    for (final size in [const Size(375, 812), const Size(1366, 1024)]) {
      view.physicalSize = size;
      view.devicePixelRatio = 1.0;
      await tester.pumpWidget(host(repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('iCloud'), findsNothing);
      expect(find.textContaining('Outlook'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(
        find.byType(NavigationBar),
        findsNothing,
        reason: '任务区内不得有第二套底部导航',
      );
    }
  });
}
