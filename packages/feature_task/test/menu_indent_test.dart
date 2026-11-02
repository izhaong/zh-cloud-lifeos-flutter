// #537「编辑 → 缩进 / 减少缩进」：菜单只投命令，层级由 feature_task 改
// `ReminderItem.parentId`（null = 顶层）。
//
// 判据盯四件事：
//  ① 「上一条」是**屏幕上真实的那一行**（含子行），不是「上一个顶层条目」——
//     这是本卡最容易写错的地方，所以专门用「顶层的第二个」去缩进，
//     期望它挂到**上一行的子项**下面；
//  ② 减无可减 / 没选中 / 自己带子任务，都给可见提示，不静默 no-op；
//  ③ 「隐藏所有子任务」时子行不渲染，行序里也不该有它们；
//  ④ 命令一律被消费（`commands.value` 归 null），重建时不会重复改层级。
import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

Future<ValueNotifier<LifeMenuAction?>> _pump(
  WidgetTester tester,
  InMemoryReminderRepository repo,
) async {
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
      child: lifeTestHost(const TaskScaffold(openListId: 'list.work')),
    ),
  );
  await tester.pumpAndSettle();
  return commands;
}

/// 可见行序（手动排序，sortOrder 0..4）：
/// 祖父项 › 父项(子行) › 中间那条 › 带子项的 › 它的子项(子行)
Future<InMemoryReminderRepository> _repo() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  await repo.upsertItem(const ReminderItem(
      id: 'g-1', listId: 'list.work', title: '祖父项', sortOrder: 0));
  await repo.upsertItem(const ReminderItem(
      id: 'c-1',
      listId: 'list.work',
      parentId: 'g-1',
      title: '父项',
      sortOrder: 1));
  await repo.upsertItem(const ReminderItem(
      id: 'm-2', listId: 'list.work', title: '中间那条', sortOrder: 2));
  await repo.upsertItem(const ReminderItem(
      id: 'p-3', listId: 'list.work', title: '带子项的', sortOrder: 3));
  await repo.upsertItem(const ReminderItem(
      id: 'k-3',
      listId: 'list.work',
      parentId: 'p-3',
      title: '它的子项',
      sortOrder: 4));
  return repo;
}

Future<ReminderItem> _itemOf(
        InMemoryReminderRepository repo, String id) async =>
    (await repo.watchItems(listId: 'list.work').first)
        .firstWhere((e) => e.id == id);

void main() {
  testWidgets('#537 缩进挂到「屏幕上的上一行」，不是上一个顶层条目', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    expect(await _itemOf(repo, 'm-2'), isA<ReminderItem>().having(
        (e) => e.parentId, 'parentId（起手是顶层）', null));

    await tester.tap(find.text('中间那条'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.indentReminder;
    await tester.pumpAndSettle();
    expect(commands.value, isNull, reason: '命令消费后必须清空');

    expect(
      (await _itemOf(repo, 'm-2')).parentId,
      'c-1',
      reason: '上一行是「父项」这条**子行**；若按顶层序会错挂到 g-1',
    );
  });

  testWidgets('#537 减少缩进升一层：子项回到顶层（父本来就是顶层）', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    await tester.tap(find.text('父项'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.outdentReminder;
    await tester.pumpAndSettle();

    expect((await _itemOf(repo, 'c-1')).parentId, isNull,
        reason: 'g-1 是顶层 ⇒ 减一层就是回到顶层');
  });

  testWidgets('#537 第一行缩进：给可见提示，数据一动不动', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    await tester.tap(find.text('祖父项'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.indentReminder;
    await tester.pumpAndSettle();

    expect(find.text('它上面没有可以归属的提醒事项'), findsOneWidget);
    expect((await _itemOf(repo, 'g-1')).parentId, isNull);
  });

  testWidgets('#537 顶层条目减少缩进：提示已在最外层', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    await tester.tap(find.text('中间那条'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.outdentReminder;
    await tester.pumpAndSettle();

    expect(find.text('这条已经在最外层'), findsOneWidget);
    expect((await _itemOf(repo, 'm-2')).parentId, isNull);
  });

  testWidgets('#537 自己带子任务时拒绝缩进（会把整棵子树搬走）', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    await tester.tap(find.text('带子项的'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.indentReminder;
    await tester.pumpAndSettle();

    expect(find.text('这条自己还有子任务，先把子任务移走'), findsOneWidget);
    expect((await _itemOf(repo, 'p-3')).parentId, isNull);
    expect((await _itemOf(repo, 'k-3')).parentId, 'p-3',
        reason: '被拒绝的操作不能顺带动到子项的归属');
  });

  testWidgets('#537 没选中条目时给可见提示，不改任何层级', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    commands.value = LifeMenuAction.indentReminder;
    await tester.pumpAndSettle();
    expect(find.text('先选中一条提醒事项'), findsOneWidget);

    commands.value = LifeMenuAction.outdentReminder;
    await tester.pumpAndSettle();
    expect(find.text('先选中一条提醒事项'), findsNWidgets(2));
    expect((await _itemOf(repo, 'c-1')).parentId, 'g-1');
  });

  testWidgets('#537 隐藏所有子任务后，行序里不该再有子行', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    commands.value = LifeMenuAction.hideSubtasks;
    await tester.pumpAndSettle();

    await tester.tap(find.text('中间那条'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.indentReminder;
    await tester.pumpAndSettle();

    expect(
      (await _itemOf(repo, 'm-2')).parentId,
      'g-1',
      reason: '子行「父项」此时不渲染 ⇒ 上一行是「祖父项」；'
          '若行序没跟随这个开关会挂到 c-1',
    );
  });
}
