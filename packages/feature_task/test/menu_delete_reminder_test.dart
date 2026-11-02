// #537 第 5 刀：macOS「编辑 → 删除提醒事项」。
//
// 删除对象是三栏里当前选中的条目（选中态归 `_ThreePane`，上一刀「移至分区…」
// 已经把这条通路接好）。这里**只**接线，不重新实现删除：级联（父删子随）与
// 30 天回收窗都是 `ReminderRepository.deleteItem` 的既有契约（TC-UI-109）。
//
// 断言盯三件事：
//  ① 删的是软删进「最近删除」，不是从存储里消失（还能恢复）；
//  ② 没有选中条目 / 已经在最近删除里，都给可见提示，不是静默 no-op；
//  ③ 菜单命令一律被消费（`commands.value` 归 null），不会重建时重复触发。
import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

Future<ValueNotifier<LifeMenuAction?>> _pump(
  WidgetTester tester,
  InMemoryReminderRepository repo, {
  String listId = 'list.work',
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final commands = ValueNotifier<LifeMenuAction?>(null);
  addTearDown(commands.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        lifeMenuCommandsProvider.overrideWithValue(commands),
      ],
      child: lifeTestHost(TaskScaffold(openListId: listId)),
    ),
  );
  await tester.pumpAndSettle();
  return commands;
}

Future<InMemoryReminderRepository> _repo() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  await repo.upsertItem(const ReminderItem(
    id: 'p-1',
    listId: 'list.work',
    title: '父项采买',
    sortOrder: 0,
  ));
  await repo.upsertItem(const ReminderItem(
    id: 'c-1',
    listId: 'list.work',
    parentId: 'p-1',
    title: '子项牛奶',
    sortOrder: 1,
  ));
  await repo.upsertItem(const ReminderItem(
    id: 'k-1',
    listId: 'list.work',
    title: '另一条',
    sortOrder: 2,
  ));
  return repo;
}

Future<Set<String>> _aliveIds(InMemoryReminderRepository repo) async {
  final items = await repo.watchItems().first;
  return items.map((e) => e.id).toSet();
}

Future<Set<String>> _trashIds(InMemoryReminderRepository repo) async {
  final items = await repo.watchItems(listId: 'smart.trash').first;
  return items.map((e) => e.id).toSet();
}

void main() {
  testWidgets('#537 选中一条 → 菜单「删除提醒事项」→ 软删进最近删除（含子项级联）',
      (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    await tester.tap(find.text('父项采买'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.deleteReminder;
    await tester.pumpAndSettle();
    expect(commands.value, isNull, reason: '命令消费后必须清空');

    expect(await _aliveIds(repo), {'k-1'}, reason: '父与子都不再存活（既有级联契约）');
    expect(await _trashIds(repo), {'p-1', 'c-1'},
        reason: '进回收窗而不是被硬删');
    expect(find.text('父项采买'), findsNothing);
    expect(find.text('另一条'), findsOneWidget, reason: '未选中的那条不受影响');
  });

  testWidgets('#537 没选中条目时给可见提示，不删任何东西', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    commands.value = LifeMenuAction.deleteReminder;
    await tester.pumpAndSettle();

    expect(find.text('先选中一条提醒事项'), findsOneWidget);
    expect(await _aliveIds(repo), {'p-1', 'c-1', 'k-1'});
    expect(await _trashIds(repo), isEmpty);
  });

  testWidgets('#537 在最近删除视图里再按删除不硬删，只提示可直接恢复',
      (tester) async {
    final repo = await _repo();
    await repo.deleteItem('k-1');
    final commands = await _pump(tester, repo, listId: 'smart.trash');

    expect(find.text('另一条'), findsOneWidget, reason: '回收站里能看到它');

    await tester.tap(find.text('另一条'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.deleteReminder;
    await tester.pumpAndSettle();

    expect(find.text('这条已在最近删除里，可直接恢复'), findsOneWidget);
    expect(await _trashIds(repo), {'k-1'}, reason: '不得被移出回收窗');
    expect(await _aliveIds(repo), {'p-1', 'c-1'});
  });
}
