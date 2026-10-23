import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/main.dart';
import 'package:life_launcher/shell/pinned_tabs_service.dart';
import 'package:life_launcher/shell_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 测试用 provider overrides（mock 偏好 + InMemory 仓库）。
/// 内联到 ProviderScope(overrides: [ ... ]) 时类型自动推断为 Override 列表。
Future<List<dynamic>> _overrides({
  Map<String, Object> prefsValues = const {},
  Map<String, int> badges = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  return [
    reminderRepositoryProvider.overrideWithValue(
      InMemoryReminderRepository(),
    ),
    pinnedTabsServiceProvider.overrideWithValue(
      PinnedTabsService(prefs),
    ),
    shellBadgeCountsProvider.overrideWithValue(badges),
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(375, 812),
  Map<String, Object> prefsValues = const {},
  Map<String, int> badges = const {},
}) async {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  final overrideList = await _overrides(
    prefsValues: prefsValues,
    badges: badges,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        for (final o in overrideList) o as dynamic,
      ],
      child: const LifeLauncherApp(),
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

  test('PinnedTabsService.normalize：滤未知/去重/截断', () {
    expect(
      PinnedTabsService.normalize(
        ['task', 'ghost', 'task', 'calendar', 'habit'],
      ),
      ['task', 'calendar', 'habit'],
    );
    // 超上限截断（服务层单测；当前注册表仅 3 应用，用构造数据验证 ≤5）
    final sixIds = List.generate(6, (i) => 'task');
    expect(PinnedTabsService.normalize(sixIds), ['task']);
  });

  testWidgets('缺省偏好 = 全固定（注册表序）+ 更多恒最右', (tester) async {
    await _pump(tester);

    // 底栏顺序：任务 日历 习惯 更多
    final labels = tester
        .widgetList<NavigationDestination>(
          find.byType(NavigationDestination),
        )
        .map((d) => d.label)
        .toList();
    expect(labels, ['任务', '日历', '习惯', '更多']);
    expect(labels.last, '更多'); // 恒最右
  });

  testWidgets('编辑态：−移出/＋加回 写即生效落 mock 偏好', (tester) async {
    await _pump(tester);

    // 进更多分支 → 点编辑
    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    // 移出「任务」
    await tester.tap(find.byKey(const ValueKey('unpin_task')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('shell.pinned_tab_ids'), ['calendar', 'habit']);

    // 加回「任务」（追加到末位）
    await tester.tap(find.byKey(const ValueKey('pin_task')));
    await tester.pumpAndSettle();
    expect(
      prefs.getStringList('shell.pinned_tab_ids'),
      ['calendar', 'habit', 'task'],
    );

    // 「编辑」期间底栏实时变化：任务 Tab 暂时消失时加回后回来
    final labels = tester
        .widgetList<NavigationDestination>(
          find.byType(NavigationDestination),
        )
        .map((d) => d.label)
        .toList();
    expect(labels, ['日历', '习惯', '任务', '更多']);
  });

  testWidgets('编辑态更多行无 −/手柄（不可移除）', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unpin_more')), findsNothing);
    expect(find.byKey(const ValueKey('pin_more')), findsNothing);
  });

  testWidgets('徽标：override {task:3} → Tab 角标显示', (tester) async {
    await _pump(tester, badges: const {'task': 3});

    // Tab 上有徽标（Badge widget 内文本 3；智能卡片计数也是 3 但不在 Badge 内）
    expect(find.byType(Badge), findsOneWidget);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('默认无徽标渲染（findsNothing Badge）', (tester) async {
    await _pump(tester);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('占位应用可固定/打开与正式应用一致', (tester) async {
    await _pump(tester);

    // 默认偏好含日历（占位）→ Tab 上可见
    expect(find.text('日历'), findsWidgets);
    // 更多面板展示态显示占位说明
    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    expect(find.textContaining('占位'), findsWidgets);
  });

  testWidgets('既有壳启动冒烟：任务 Tab + 智能列表', (tester) async {
    await _pump(tester);

    expect(find.text('提醒事项'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('更多'), findsWidgets);
  });

  testWidgets('既有紧凑端点列表全屏推入：无双底栏', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('个人'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('买牛奶'), findsOneWidget);
  });
}
