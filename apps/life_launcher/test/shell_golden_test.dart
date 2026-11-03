import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/main.dart';
import 'package:life_launcher/shell/pinned_tabs_service.dart';
import 'package:life_launcher/shell_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App 壳的三档 golden（#335）。
///
/// 壳里若有「今天」类高亮，必须走 `clockProvider`（#331/#333 的口径），
/// 否则图会随执行日期漂移。
void main() {
  final fixed = DateTime(2026, 10, 26, 9, 30);

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    List<ReminderList> seedLists = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final repo = InMemoryReminderRepository()..nowForTest = fixed;
    for (final list in seedLists) {
      await repo.upsertList(list);
    }
    await repo.upsertItem(
      ReminderItem(
        id: 'r1',
        listId: 'list.default',
        title: '周报',
        dueAt: DateTime(2026, 10, 26, 10),
        createdAt: DateTime(2026, 10, 26, 9),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          pinnedTabsServiceProvider.overrideWithValue(PinnedTabsService(prefs)),
          shellBadgeCountsProvider.overrideWithValue(const {'task': 3}),
          clockProvider.overrideWithValue(() => fixed),
        ],
        child: const LifeLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('桌面 1280 暗色（golden 基线；同夹具只改明暗）', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpAt(tester, const Size(1280, 800));
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/desktop_1280_shell_dark.png'),
    );
  });

  testWidgets('iPhone 375（golden 基线；挂钟注入固定 2026-10-26）', (tester) async {
    await pumpAt(tester, const Size(375, 812));
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/iphone_375_shell.png'),
    );
  });

  testWidgets('iPhone 375 进列表（golden 基线；条目级）', (tester) async {
    await pumpAt(tester, const Size(375, 812));
    // 375 首屏是紧凑概览，不渲染条目；点进列表才有条目级内容（#337）。
    await tester.tap(find.text('今天').first);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/iphone_375_task_list.png'),
    );
  });

  testWidgets('iPad 834（golden 基线；挂钟注入固定 2026-10-26）', (tester) async {
    await pumpAt(tester, const Size(834, 1112));
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/ipad_834_shell.png'),
    );
  });

  testWidgets('桌面 1280（golden 基线；挂钟注入固定 2026-10-26）', (tester) async {
    await pumpAt(tester, const Size(1280, 800));
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/desktop_1280_shell.png'),
    );
  });

  testWidgets('桌面 1280 已置顶清单排在最前（service#591 之后，flutter#564 呈现取证）', (
    tester,
  ) async {
    // sortOrder 故意与期望的视觉序相反：置顶压不过手动顺序的话，这张图就什么都不是。
    await pumpAt(
      tester,
      const Size(1280, 800),
      seedLists: [
        const ReminderList(id: 'list.plain', title: '未置顶清单', sortOrder: 0),
        const ReminderList(id: 'list.pin', title: '已置顶清单', sortOrder: 1, isPinned: true),
      ],
    );
    final pinned = find.byKey(const ValueKey('my_list_list.pin'));
    final plain = find.byKey(const ValueKey('my_list_list.plain'));
    expect(pinned, findsOneWidget, reason: '置顶清单必须真的渲染在侧栏上，找不到行就等于没取证');
    expect(plain, findsOneWidget, reason: '未置顶清单同理');
    expect(
      tester.getTopLeft(pinned).dy,
      lessThan(tester.getTopLeft(plain).dy),
      reason: '#564 判据 ①：置顶行的 y 坐标必须在未置顶行之上（量坐标，不量文案存在）',
    );
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/desktop_1280_list_pinned_first.png'),
    );
  });
}
