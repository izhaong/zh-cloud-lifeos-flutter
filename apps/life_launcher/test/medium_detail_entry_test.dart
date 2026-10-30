import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/main.dart';
import 'package:life_launcher/shell/pinned_tabs_service.dart';
import 'package:life_launcher/shell_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// parity#172：窗口缩放跨档时「点提醒 → 出详情」的判据。
///
/// #159 把 `_openDetail` 的判据从 `isPaneLayout`（medium+expanded）收窄为
/// `expanded`，但没留自动化判据：改回 `isPaneLayout` 全量测试仍全绿。
/// 这里按 500 / 900 / 1200 三档钉住「详情可达」与「模态 vs 第三栏互斥」。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<InMemoryReminderRepository> seed() async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '个人'));
    final now = DateTime.now();
    await repo.upsertItem(
      ReminderItem(
        id: 'r1',
        listId: 'list.a',
        title: '甲提醒',
        dueAt: DateTime(now.year, now.month, now.day),
      ),
    );
    return repo;
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    required Size size,
    required InMemoryReminderRepository repo,
  }) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          pinnedTabsServiceProvider.overrideWithValue(PinnedTabsService(prefs)),
          shellBadgeCountsProvider.overrideWithValue(const {}),
        ],
        child: const LifeLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('medium 900：点提醒弹出模态详情（不是死点）', (tester) async {
    final repo = await seed();
    await pumpApp(tester, size: const Size(900, 900), repo: repo);

    await tester.tap(find.text('甲提醒'));
    await tester.pumpAndSettle();

    expect(find.byType(ReminderDetailPane), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
      isTrue,
      reason: 'medium 走模态路由',
    );
    // #481：不再是遮挡列表的底部抽屉，而是右侧锚定弹窗
    expect(
      find.byKey(const ValueKey('detail_popover')),
      findsOneWidget,
      reason: 'medium 详情是锚定弹窗',
    );
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(
      find.text('甲提醒'),
      findsWidgets,
      reason: '列表仍在弹窗后面可见（行 + 详情标题各一处）',
    );
  });

  testWidgets('expanded 1280：点提醒出第三栏 inspector，不弹模态', (tester) async {
    final repo = await seed();
    await pumpApp(tester, size: const Size(1280, 900), repo: repo);

    await tester.tap(find.text('甲提醒'));
    await tester.pumpAndSettle();

    expect(find.byType(ReminderDetailPane), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
      isFalse,
      reason: 'expanded 是就地 inspector，不应 push 路由',
    );
  });

  testWidgets('compact 500：智能卡 → 列表 → 点行弹模态详情', (tester) async {
    final repo = await seed();
    await pumpApp(tester, size: const Size(500, 900), repo: repo);

    await tester.tap(find.byKey(const ValueKey('smart_card_smart.today')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('甲提醒'));
    await tester.pumpAndSettle();

    expect(find.byType(ReminderDetailPane), findsOneWidget);
    // #481：紧凑档按 iPhone 口径整页推入（有可关闭导航栏），不是底部抽屉
    expect(find.byKey(const ValueKey('detail_close')), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.byKey(const ValueKey('detail_popover')), findsNothing);
  });
}
