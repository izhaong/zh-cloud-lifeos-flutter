// #537 B 类第 1 面：macOS「显示 → 显示所有子任务 / 隐藏所有子任务」。
//
// 子任务目前恒随父行渲染（`_buildItemRow` 里 `for (final sub in subs)`），
// Apple 的这条菜单是整体开关。开关值落在 collapsedKeys 这条**已持久化**的
// 视图态键袋里（它本来就带 `<listId>|<分区标题>` 与 `group:<分组名>` 两个命名空间，
// 这里加第三个 `view:` 命名空间）——不加 Drift 列的理由见 PR 正文。
//
// 两条最容易被这类"隐藏"改坏的东西各自有断言：
//  ① 隐藏只是不渲染子行，**不得**把子任务提升成顶层行（子任务若跑到顶层，
//     列表会凭空多出几行，且失去缩进层级）；
//  ② 隐藏不得改数据（仓库里父子关系与条数必须原样）。
import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

Future<ValueNotifier<LifeMenuAction?>> _pump(
  WidgetTester tester,
  ReminderRepository repo,
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

/// 一条父 + 两条子；三条文案互不相同，才能按"某条在不在"判渲染。
Future<InMemoryReminderRepository> _repo() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  await repo.upsertItem(const ReminderItem(
    id: 'p-1',
    listId: 'list.work',
    title: '父项采买',
  ));
  await repo.upsertItem(const ReminderItem(
    id: 's-1',
    listId: 'list.work',
    parentId: 'p-1',
    title: '子项牛奶',
  ));
  await repo.upsertItem(const ReminderItem(
    id: 's-2',
    listId: 'list.work',
    parentId: 'p-1',
    title: '子项面包',
  ));
  return repo;
}

void main() {
  testWidgets('#537 默认显示子任务；菜单「隐藏所有子任务」后子行消失、父行仍在',
      (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    expect(find.text('父项采买'), findsOneWidget);
    expect(find.text('子项牛奶'), findsOneWidget, reason: '默认随父行渲染');
    expect(find.text('子项面包'), findsOneWidget);

    commands.value = LifeMenuAction.hideSubtasks;
    await tester.pumpAndSettle();
    expect(commands.value, isNull, reason: '命令消费后必须清空');

    expect(find.text('父项采买'), findsOneWidget, reason: '父行不受影响');
    expect(find.text('子项牛奶'), findsNothing);
    expect(find.text('子项面包'), findsNothing);

    // 隐藏 ≠ 提升：子任务不能因为父的展开开关而变成顶层行冒出来
    // （上面 findsNothing 已覆盖"换个位置出现"，这里再证仓库侧完全没动）。
    final items = await repo.watchItems().first;
    expect(items.length, 3, reason: '视图开关不得改数据');
    expect(items.firstWhere((e) => e.id == 's-1').parentId, 'p-1');

    commands.value = LifeMenuAction.showAllSubtasks;
    await tester.pumpAndSettle();
    expect(find.text('子项牛奶'), findsOneWidget, reason: '再显示要回到原状');
    expect(find.text('子项面包'), findsOneWidget);
  });

  testWidgets('#537 开关落在已持久化的视图态键袋里（重启后可回落的行为可测）',
      (tester) async {
    final repo = await _repo();
    final container = ProviderContainer(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    expect(container.read(collapsedKeysProvider).contains('view:subtasksHidden'),
        isFalse,
        reason: '默认显示所有子任务');
    container.read(collapsedKeysProvider.notifier).setSubtasksHidden(true);
    expect(container.read(collapsedKeysProvider), contains('view:subtasksHidden'));

    // 与分区折叠键共存：一个视图开关不该把另一类已存的键冲掉。
    container.read(collapsedKeysProvider.notifier).toggle('list.work|收件箱');
    expect(container.read(collapsedKeysProvider),
        containsAll(<String>['view:subtasksHidden', 'list.work|收件箱']));
    container.read(collapsedKeysProvider.notifier).setSubtasksHidden(false);
    expect(container.read(collapsedKeysProvider),
        equals(<String>{'list.work|收件箱'}));
  });
}
