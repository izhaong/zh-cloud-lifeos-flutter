import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TC-UI-110 手动分区（M2）：列表带分区元数据时按 sectionId 分组渲染；
/// 折叠/展开；未分区兜底；与 dueAt 日桶互斥（一列表一种模式）。
Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required ReminderRepository repo,
  Widget child = const TaskScaffold(openListId: 'list.work'),
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

  testWidgets('TC-UI-110 手动分区渲染：按元数据序 + 未分区兜底',
      (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
    await repo.upsertSection(
      listId: 'list.work',
      section: const ReminderSection(id: 's1', title: '进行中', sortOrder: 0),
    );
    await repo.upsertSection(
      listId: 'list.work',
      section: const ReminderSection(id: 's2', title: '收尾', sortOrder: 1),
    );
    await repo.upsertItem(
      const ReminderItem(
        id: 'a',
        listId: 'list.work',
        title: '分区任务A',
        sectionId: 's1',
      ),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'b', listId: 'list.work', title: '无分区任务B'),
    );

    await _pump(tester, size: const Size(834, 1112), repo: repo);

    // 分区头按元数据序（进行中、收尾、未分区恒尾）
    expect(find.byKey(const ValueKey('section_进行中')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_收尾')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_未分区')), findsOneWidget);

    // 条目落对桶
    expect(find.text('分区任务A'), findsOneWidget);
    expect(find.text('无分区任务B'), findsOneWidget);
  });

  testWidgets('TC-UI-110 分区折叠与互斥：手动模式不出现日桶头', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
    await repo.upsertSection(
      listId: 'list.work',
      section: const ReminderSection(id: 's1', title: '进行中'),
    );
    // 有 dueAt 的条目在手动模式下也进「未分区」（互斥：不再按日分桶）
    await repo.upsertItem(
      ReminderItem(
        id: 'c',
        listId: 'list.work',
        title: '带日期但未分区',
        dueAt: DateTime.now(),
      ),
    );

    await _pump(tester, size: const Size(834, 1112), repo: repo);

    // 手动模式：无「今天/无日期」日桶头
    expect(find.byKey(const ValueKey('section_今天')), findsNothing);
    expect(find.byKey(const ValueKey('section_无日期')), findsNothing);
    expect(find.text('带日期但未分区'), findsOneWidget); // 进未分区

    // 折叠「进行中」空分区
    await tester.tap(find.byKey(const ValueKey('section_进行中')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('section_进行中')), findsOneWidget); // 头仍在
  });

  testWidgets('TC-UI-110 无分区元数据回退日桶（互斥另一侧）', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
    final now = DateTime.now();
    await repo.upsertItem(
      ReminderItem(
        id: 'd',
        listId: 'list.work',
        title: '今日任务',
        dueAt: now,
      ),
    );

    await _pump(tester, size: const Size(834, 1112), repo: repo);

    // 无手动分区 → 日桶生效
    expect(find.byKey(const ValueKey('section_今天')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_未分区')), findsNothing);
  });
}
