// #702：排序「手动」时不得再按 dueAt 时间分组。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('#702 手动排序（默认）→ 无时间组头', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1.0;

    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
    final now = DateTime(2026, 10, 26, 9);
    await repo.upsertItem(
      ReminderItem(
        id: 'a',
        listId: 'list.work',
        title: '有日期',
        dueAt: now,
      ),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'b', listId: 'list.work', title: '无日期项'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => now),
        ],
        child: lifeTestHost(const TaskScaffold(openListId: 'list.work')),
      ),
    );
    await tester.pumpAndSettle();

    // 默认 ListSortMode.manual：扁平列表，不应出现 dueAt 日桶头。
    expect(find.byKey(const ValueKey('section_无日期')), findsNothing);
    expect(find.byKey(const ValueKey('section_今天')), findsNothing);
    expect(find.text('有日期'), findsOneWidget);
    expect(find.text('无日期项'), findsOneWidget);
  });
}
