// TC-UI-201 补强（#375）：菜单「文件 → 新建提醒事项」必须有接收方。
import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('#375 菜单命令 newReminder → 任务页出现草稿行', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryReminderRepository(seedSampleData: false)
      ..nowForTest = DateTime(2026, 10, 26);
    final commands = ValueNotifier<LifeMenuAction?>(null);
    addTearDown(commands.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 9)),
          lifeMenuCommandsProvider.overrideWithValue(commands),
        ],
        child: const MaterialApp(home: TaskScaffold(openListId: 'smart.today')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('draft_field')), findsNothing,
        reason: '初始不该有草稿行');

    commands.value = LifeMenuAction.newReminder;
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('draft_field')), findsOneWidget,
        reason: '菜单命令应打开草稿行（与「＋ 新提醒事项」同一路径）');
    expect(commands.value, isNull, reason: '消费后必须清空');
  });
}
