import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 壳根组件在 main.dart（无库导出文件；测试直接引用）
// ignore: implementation_imports
import 'package:life_launcher/main.dart' show LifeLauncherApp;
import 'package:life_launcher/shell_providers.dart' show pinnedTabsServiceProvider;
import 'package:life_launcher/shell/pinned_tabs_service.dart' show PinnedTabsService;

/// TC-SYNC-101（T-05）：全新安装冷启动——未登录直接进生活台任务本地功能，
/// 无强制登录弹窗（离线优先红线 §4.1）。
void main() {
  testWidgets('TC-SYNC-101 冷启动未登录：直达任务区，无强制登录弹窗',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;

    // 冷启动默认态：authPortProvider=Noop（currentSession=null）
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authPortProvider.overrideWithValue(const NoopAuthPort()),
          syncPortProvider.overrideWithValue(const NoopSyncPort()),
          reminderRepositoryProvider.overrideWithValue(
            InMemoryReminderRepository(),
          ),
          pinnedTabsServiceProvider.overrideWithValue(PinnedTabsService(prefs)),
        ],
        child: const LifeLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 无强制登录弹窗：无「登录」拦截层
    expect(find.text('登录'), findsNothing);
    expect(find.text('跳过'), findsNothing);
    // 任务本地功能直达：壳在（任务 Tab 常显）
    expect(find.text('任务'), findsWidgets);
  });
}
