import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/main.dart';

void main() {
  testWidgets('壳启动：任务 Tab + 更多最右 + 智能列表', (tester) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(375, 812);
    view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(
            InMemoryReminderRepository(),
          ),
        ],
        child: const LifeLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('提醒事项'), findsOneWidget);
    expect(find.text('更多'), findsWidgets);
    expect(find.text('今天'), findsOneWidget);

    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('紧凑端点列表全屏推入：无双底栏', (tester) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(375, 812);
    view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(
            InMemoryReminderRepository(),
          ),
        ],
        child: const LifeLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 点「个人」列表 → shell 外顶层路由 → 底部 NavigationBar 消失
    await tester.tap(find.text('个人'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('买牛奶'), findsOneWidget);

    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
}
