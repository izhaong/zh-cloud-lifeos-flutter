// FL #595（口径 1）：同步状态只在设置弹层可见——主界面保持 #592 量到的「静默」。
import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

void main() {
  Future<void> openSheet(WidgetTester tester, SyncStatus? status) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(420, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(
            InMemoryReminderRepository(seedSampleData: false),
          ),
          // 未注入 = 开源默认（signedOut），用来当「默认不许摆状态」的对照。
          if (status != null)
            syncStatusProvider.overrideWith((ref) async => status),
        ],
        child: lifeTestHost(
          Builder(
            builder: (ctx) => CupertinoButton(
              child: const Text('打开设置'),
              onPressed: () =>
                  showTaskSettingsSheet(ctx, onOpenCloudLogin: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle();
  }

  testWidgets('#595 已登录 + 有待推 + 成功同步过：副标题把三件事一次说清',
      (tester) async {
    await openSheet(
      tester,
      SyncStatus(
        loggedIn: true,
        pendingCount: 2,
        lastSyncAt: DateTime(2026, 11, 3, 9, 41),
      ),
    );
    expect(find.text('待推 2 条 · 上次同步 09:41'), findsOneWidget);
  });

  testWidgets('#595 已登录但从没成功同步过：说「尚未同步」，不摆 00:00 这种假值',
      (tester) async {
    await openSheet(
      tester,
      const SyncStatus(loggedIn: true, pendingCount: 0),
    );
    expect(find.text('待推 0 条 · 尚未同步'), findsOneWidget);
    expect(find.textContaining('上次同步'), findsNothing);
  });

  testWidgets('#595 注入未登录：不摆副标题，标题仍是「开启云同步」', (tester) async {
    await openSheet(tester, const SyncStatus.signedOut());
    expect(find.textContaining('待推'), findsNothing);
    expect(find.text('开启云同步'), findsOneWidget);
  });

  testWidgets('#595 什么都没注入（开源默认）：也不摆副标题——默认不许自己编出同步状态',
      (tester) async {
    // 单独一条用例：Riverpod 不允许在同一棵树里改变 overrides 的数量。
    await openSheet(tester, null);
    expect(find.textContaining('待推'), findsNothing);
  });
}
