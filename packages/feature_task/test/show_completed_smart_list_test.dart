import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

/// parity#180：「显示已完成」必须在**智能列表**（今天/全部）生效。
///
/// 完成过滤原先只存在于仓库层，智能列表永远不返回已完成项，UI 层的开关
/// 因此无处可显；TC-UI-108 的用例只覆盖普通列表，真机走查才发现。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('智能列表「今天」打开显示已完成后出现已完成项', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '列表A'));
    final now = DateTime.now();
    await repo.upsertItem(
      ReminderItem(
        id: 'open1',
        listId: 'list.a',
        title: '未完成项',
        dueAt: DateTime(now.year, now.month, now.day, 9),
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'done1',
        listId: 'list.a',
        title: '已完成项',
        dueAt: DateTime(now.year, now.month, now.day, 10),
      ),
    );
    await repo.toggleCompleted('done1');

    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1366, 1024)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(
          const TaskScaffold(openListId: 'smart.today'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('未完成项'), findsOneWidget);
    expect(find.text('已完成项'), findsNothing, reason: '默认隐藏已完成');

    await tester.tap(find.byKey(const ValueKey('toggle_show_completed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('显示已完成').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('已完成项'),
      findsOneWidget,
      reason: '智能列表也要接收「显示已完成」偏好',
    );
  });
}
