import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'support/life_test_app.dart';

/// 回归：今日视图新建项必须出现在今日视图（用户实测反馈 bug）。
///
/// 根因：`_submitDraft` 智能视图新建项 `dueAt: null` →
/// `smart.today` 过滤 `!completed && 同日` 不命中 → 项虽落库但视图不可见。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('今日视图新建项 → 出现在今日视图', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(
        id: 'list.personal',
        title: '提醒事项',
        colorArgb: 0xFFFF9500,
      ),
    );

    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(375, 812);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(const TaskScaffold(openListId: 'smart.today')),
      ),
    );
    await tester.pumpAndSettle();

    // 无初始条目（空态）
    expect(find.text('没有提醒'), findsOneWidget);

    // 底栏「新提醒事项」→ 输入 → 提交
    await tester.tap(find.byKey(const ValueKey('bottom_new_item')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('draft_field')), '测试今日新建');
    // 草稿行 TextField.onSubmitted = Enter 提交
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // 关键断言：项出现在今日视图（非空态消失、条目可见）
    expect(
      find.text('测试今日新建'),
      findsOneWidget,
      reason: '今日视图新建项必须显示——dueAt=now 后 smart.today 过滤命中',
    );
    expect(find.text('没有提醒'), findsNothing, reason: '空态应让位');

    // 仓库中项确实带 dueAt=今天
    final all = await repo.watchItems().first;
    final item = all.singleWhere((e) => e.title == '测试今日新建');
    expect(item.dueAt, isNotNull, reason: '今日视图新建必须设 dueAt');
  });

  testWidgets('计划视图新建项 → 带 dueAt 出现在计划视图', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(
        id: 'list.personal',
        title: '提醒事项',
        colorArgb: 0xFFFF9500,
      ),
    );

    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(375, 812);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(const TaskScaffold(openListId: 'smart.scheduled')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom_new_item')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('draft_field')), '计划新建');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // smart.scheduled 过滤 = !completed && dueAt != null
    final all = await repo.watchItems().first;
    final item = all.singleWhere((e) => e.title == '计划新建');
    expect(item.dueAt, isNotNull, reason: '计划视图新建必须带 dueAt 才能命中 scheduled 过滤');
  });
}
