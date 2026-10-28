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

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final repo = InMemoryReminderRepository()..nowForTest = fixed;
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

  testWidgets('iPhone 375（golden 基线；挂钟注入固定 2026-10-26）', (tester) async {
    await pumpAt(tester, const Size(375, 812));
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/iphone_375_shell.png'),
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
}
