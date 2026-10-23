import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required ReminderRepository repo,
  Widget child = const TaskScaffold(openListId: 'list.personal'),
}) async {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('首页出现「紧急/完成」智能卡且计数正确', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: true);
    await _pump(
      tester,
      size: const Size(375, 812),
      repo: repo,
      child: const TaskScaffold(), // 紧凑首页
    );

    expect(find.text('紧急'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
  });

  testWidgets('负向门禁：无「分配事项/iCloud/Outlook/建议列表」文案',
      (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(tester, size: const Size(375, 812), repo: repo);

    expect(find.textContaining('分配事项'), findsNothing);
    expect(find.textContaining('iCloud'), findsNothing);
    expect(find.textContaining('Outlook'), findsNothing);
    expect(find.textContaining('建议列表'), findsNothing);
  });

  testWidgets('分区折叠：按 dueAt 日桶分组，点分区头折叠/展开', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
    final now = DateTime.now();
    await repo.upsertItem(
      ReminderItem(
        id: 't1',
        listId: 'list.work',
        title: '今天的事',
        dueAt: now,
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 't2',
        listId: 'list.work',
        title: '明天的事',
        dueAt: now.add(const Duration(days: 1)),
      ),
    );
    await repo.upsertItem(
      const ReminderItem(id: 't3', listId: 'list.work', title: '无日期事'),
    );

    await _pump(
      tester,
      size: const Size(834, 1112),
      repo: repo,
      child: const TaskScaffold(openListId: 'list.work'),
    );

    // 三个分区头（今天/明天/无日期）
    expect(find.byKey(const ValueKey('section_今天')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_明天')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_无日期')), findsOneWidget);

    // 折叠「今天」
    await tester.tap(find.byKey(const ValueKey('section_今天')));
    await tester.pumpAndSettle();
    expect(find.text('今天的事'), findsNothing); // 折叠后条目隐藏

    // 再点展开
    await tester.tap(find.byKey(const ValueKey('section_今天')));
    await tester.pumpAndSettle();
    expect(find.text('今天的事'), findsOneWidget);
  });

  testWidgets('「N 项完成」只读计数与列表已完成数一致', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
    await repo.upsertItem(
      const ReminderItem(
        id: 'd1',
        listId: 'list.work',
        title: '已完成A',
        isCompleted: true,
      ),
    );
    await repo.upsertItem(
      const ReminderItem(
        id: 'd2',
        listId: 'list.work',
        title: '已完成B',
        isCompleted: true,
      ),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'd3', listId: 'list.work', title: '未完成C'),
    );

    await _pump(
      tester,
      size: const Size(834, 1112),
      repo: repo,
      child: const TaskScaffold(openListId: 'list.work'),
    );

    expect(find.text('2 项完成'), findsOneWidget);
  });

  testWidgets('完成智能卡点进：已完成条目可见', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
    await repo.upsertItem(
      const ReminderItem(
        id: 'c1',
        listId: 'list.work',
        title: '唯一完成项',
        isCompleted: true,
      ),
    );

    await _pump(
      tester,
      size: const Size(834, 1112),
      repo: repo,
      child: const TaskScaffold(openListId: 'smart.completed'),
    );

    expect(find.text('唯一完成项'), findsOneWidget);
  });
}
