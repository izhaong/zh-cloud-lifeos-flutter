import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('紧凑首页：彩色智能卡 + 建议列表 + 最近删除行', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: true);
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TaskScaffold()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('smart_card_smart.today')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('smart_card_smart.assigned')), findsOneWidget);
    expect(find.byKey(const ValueKey('smart_card_smart.trash')), findsNothing,
        reason: '最近删除是列表行，不是智能卡');
    expect(find.text('个人'), findsWidgets);
    expect(find.byKey(const ValueKey('suggested_grocery_home')), findsOneWidget);
    expect(find.text('最近删除'), findsOneWidget);
  });
}
