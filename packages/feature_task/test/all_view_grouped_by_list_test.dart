// #478：「全部」智能列表按**提醒事项列表**分组，不按日期分桶。
// 对照物：zh-cloud-docs lifeos/task/guide/mac/zh-cn/14-在Mac上查看提醒事项列表.md:25
//   「*全部：* “全部”智能列表显示全部账户中的所有提醒事项。提醒事项会按提醒事项列表分组。」
// （同段第 24 行的「计划」才写明「按日期分组」——两档分组模式不同。）
//
// 判红设计：修复前 smart.all 走通用日期标签分支，组头是 `无日期` / `今天`，
// 「列表组头存在」与「日期组头不存在」两条断言同时红；再钉「组内不混排」——
// 工作组头必须在家庭组头之上，且工作的两条条目都夹在两个头之间。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void _useDesktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  ReminderRepository repo,
  String listId,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: TaskScaffold(openListId: listId)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('「全部」按列表分组：组头是清单名，无日期/今天桶不出现', (tester) async {
    _useDesktopView(tester);
    final now = DateTime.now();
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
    await repo.upsertList(const ReminderList(id: 'list.home', title: '家庭'));
    await repo.upsertItem(
      const ReminderItem(id: 'w-undated', listId: 'list.work', title: '工作的无日期项'),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'w-today',
        listId: 'list.work',
        title: '工作的今天项',
        dueAt: DateTime(now.year, now.month, now.day, 10),
      ),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'h-undated', listId: 'list.home', title: '家庭的无日期项'),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'h-today',
        listId: 'list.home',
        title: '家庭的今天项',
        dueAt: DateTime(now.year, now.month, now.day, 11),
      ),
    );

    await _pump(tester, repo, 'smart.all');

    expect(
      find.byKey(const ValueKey('section_工作')),
      findsOneWidget,
      reason: '#478：「全部」要按提醒事项列表建组',
    );
    expect(
      find.byKey(const ValueKey('section_家庭')),
      findsOneWidget,
      reason: '#478：第二个清单同样成组',
    );
    expect(
      find.byKey(const ValueKey('section_无日期')),
      findsNothing,
      reason: '#478：日期桶不是「全部」的分组模式',
    );
    expect(
      find.byKey(const ValueKey('section_今天')),
      findsNothing,
      reason: '#478：日期桶不是「全部」的分组模式',
    );

    final workY = tester
        .getTopLeft(find.byKey(const ValueKey('section_工作')))
        .dy;
    final homeY = tester
        .getTopLeft(find.byKey(const ValueKey('section_家庭')))
        .dy;
    expect(workY, lessThan(homeY), reason: '组序跟边栏清单序（工作 → 家庭）');
    expect(
      tester.getTopLeft(find.text('工作的无日期项')).dy,
      inInclusiveRange(workY, homeY),
    );
    expect(
      tester.getTopLeft(find.text('工作的今天项')).dy,
      inInclusiveRange(workY, homeY),
      reason: '同一清单的无日期与今天项不能拆进两个日期组',
    );
    expect(tester.getTopLeft(find.text('家庭的无日期项')).dy, greaterThan(homeY));
    expect(tester.getTopLeft(find.text('家庭的今天项')).dy, greaterThan(homeY));
  });

  testWidgets('「计划」仍按日期分组（#478 不改这档）', (tester) async {
    _useDesktopView(tester);
    final now = DateTime.now();
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
    await repo.upsertItem(
      ReminderItem(
        id: 'w-tomorrow',
        listId: 'list.work',
        title: '明天项',
        dueAt: DateTime(now.year, now.month, now.day + 1, 10),
      ),
    );

    await _pump(tester, repo, 'smart.scheduled');

    expect(
      find.byKey(const ValueKey('section_明天')),
      findsOneWidget,
      reason: 'guide 14:24「计划」按日期分组，本卡不动',
    );
    expect(find.byKey(const ValueKey('section_工作')), findsNothing);
  });
}
