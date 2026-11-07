import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoButton;
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

/// parity#676：Apple 的「今天」等智能视图没有「N 项完成 · 清除」这一行；
/// 只有自有列表才有。智能视图的完成项由仓库层按语义过滤，计数结构上恒 0，
/// 留着就是一个永远点不动的死控件。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<InMemoryReminderRepository> seed() async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '列表A'));
    final now = DateTime.now();
    final today9 = DateTime(now.year, now.month, now.day, 9);
    await repo.upsertItem(
      ReminderItem(id: 'open1', listId: 'list.a', title: '未完成项', dueAt: today9),
    );
    await repo.upsertItem(
      ReminderItem(id: 'done1', listId: 'list.a', title: '已完成项', dueAt: today9),
    );
    await repo.toggleCompleted('done1');
    return repo;
  }

  Future<void> pumpList(
    WidgetTester tester,
    InMemoryReminderRepository repo,
    String listId,
  ) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1366, 1024)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(TaskScaffold(openListId: listId)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final smartId in ['smart.today', 'smart.scheduled', 'smart.all']) {
    testWidgets('$smartId 头部不出现「N 项完成 · 清除」', (tester) async {
      await pumpList(tester, await seed(), smartId);
      expect(
        find.byKey(const ValueKey('list_header_toolbar')),
        findsOneWidget,
        reason: '头部工具条本身还在（显示/排序入口）',
      );
      expect(find.byKey(const ValueKey('done_count')), findsNothing);
      expect(find.byKey(const ValueKey('clear_completed')), findsNothing);
    });
  }

  testWidgets('「完成」智能清单保留该行且清除可点（例外分支守卫）', (tester) async {
    await pumpList(tester, await seed(), 'smart.completed');
    expect(find.byKey(const ValueKey('done_count')), findsOneWidget,
        reason: '这里计数与清除都成立，不能被顺手简化成 !list.isSmart 一并隐藏');
    final clear = tester.widget<CupertinoButton>(
      find.byKey(const ValueKey('clear_completed')),
    );
    expect(clear.onPressed, isNotNull);
  });

  testWidgets('自有列表仍显示「1 项完成 · 清除」且可点（防恒真）', (tester) async {
    await pumpList(tester, await seed(), 'list.a');
    expect(find.text('1 项完成'), findsOneWidget);
    final clear = tester.widget<CupertinoButton>(
      find.byKey(const ValueKey('clear_completed')),
    );
    expect(clear.onPressed, isNotNull);
  });
}
