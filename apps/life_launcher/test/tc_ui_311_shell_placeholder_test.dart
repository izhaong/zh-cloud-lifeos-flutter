import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/main.dart';
import 'package:life_launcher/shell/pinned_tabs_service.dart';
import 'package:life_launcher/shell_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #1 线框收口审计 · 壳层占位链路
/// TC-UI-311：基座·日历 → 另文件占位（不误入任务区）。
/// 装配走真实 LifeLauncherApp + GoRouter（同 smoke_test 口径），
/// 路由若误把日历指到任务区，本用例必须变红。
void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('TC-UI-311 基座·日历占位：Tab 切到日历显示占位不进任务区',
      (tester) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view
      ..physicalSize = const Size(375, 812)
      ..devicePixelRatio = 1.0;
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(
            InMemoryReminderRepository(),
          ),
          pinnedTabsServiceProvider.overrideWithValue(
            PinnedTabsService(prefs),
          ),
          shellBadgeCountsProvider.overrideWithValue(const {}),
        ],
        child: const LifeLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 初始任务区在屏（首页 AppBar 大标题=「列表」，对齐 iOS 提醒事项）
    expect(find.text('列表'), findsOneWidget);

    // 点「日历」Tab → 真实路由 /calendar 的 PlaceholderPage
    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();

    expect(find.textContaining('待拆入'), findsWidgets);
    expect(find.text('列表'), findsNothing); // 任务区不在前台
  });
}
