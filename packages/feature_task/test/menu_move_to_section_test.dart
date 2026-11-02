// #537 第 4 刀：macOS「文件 → 移至分区…」。
//
// 操作对象是三栏里当前选中的条目（选中态归 `_ThreePane`），分区选择器与写回
// 都在 `feature_task`，菜单侧只投命令——判据见 life_launcher 的源码扫描测试。
// 弹层形态复用「编辑列表」那面同一个 `CupertinoActionSheet`，不另造选择器。
//
// 三条最容易改坏的东西各自有断言：
//  ① 只动选中的那一条，别的条目不得被顺带改 sectionId；
//  ② 「不在分区」是移出（sectionId 归 null），不是删除条目；
//  ③ 没选中 / 没分区时给的是可见提示，不是静默 no-op。
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

/// 一个带两个分区的列表 + 三条条目（其中「写周报」已挂在「日常」分区）。
Future<InMemoryReminderRepository> _repo() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  await repo.upsertSection(
    listId: 'list.work',
    section: const ReminderSection(id: 'sec-buy', title: '采买', sortOrder: 0),
  );
  await repo.upsertSection(
    listId: 'list.work',
    section: const ReminderSection(id: 'sec-daily', title: '日常', sortOrder: 1),
  );
  await repo.upsertItem(const ReminderItem(
    id: 'a',
    listId: 'list.work',
    title: '买牛奶',
    sortOrder: 0,
  ));
  await repo.upsertItem(const ReminderItem(
    id: 'b',
    listId: 'list.work',
    title: '买电池',
    sectionId: 'sec-buy',
    sortOrder: 1,
  ));
  await repo.upsertItem(const ReminderItem(
    id: 'c',
    listId: 'list.work',
    title: '写周报',
    sectionId: 'sec-daily',
    sortOrder: 2,
  ));
  return repo;
}

Future<Map<String, String?>> _sectionIdById(ReminderRepository repo) async {
  final items = await repo.watchItems().first;
  return {for (final e in items) e.id: e.sectionId};
}

void main() {
  testWidgets('#537 选中一条 → 菜单「移至分区…」→ 点分区只改那一条',
      (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    await tester.tap(find.text('买牛奶'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.moveToSection;
    await tester.pumpAndSettle();
    expect(commands.value, isNull, reason: '命令消费后必须清空');

    expect(find.byKey(const ValueKey('move_to_section_sec-buy')), findsOneWidget);
    expect(find.byKey(const ValueKey('move_to_section_sec-daily')), findsOneWidget);
    expect(find.text('不在分区'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('move_to_section_sec-buy')));
    await tester.pumpAndSettle();

    expect(await _sectionIdById(repo), {
      'a': 'sec-buy',
      'b': 'sec-buy',
      'c': 'sec-daily',
    }, reason: '只有选中的 a 变了，b/c 不得被顺带动到');
  });

  testWidgets('#537 「不在分区」是移出分区，不是删条目', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    await tester.tap(find.text('写周报'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.moveToSection;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move_to_section_none')));
    await tester.pumpAndSettle();

    final items = await repo.watchItems().first;
    expect(items.length, 3, reason: '移出分区不得少一条');
    expect(
      items.firstWhere((e) => e.id == 'c').sectionId,
      isNull,
      reason: '「不在分区」= sectionId 归 null',
    );
    expect(await _sectionIdById(repo), {'a': null, 'b': 'sec-buy', 'c': null});
  });

  testWidgets('#537 取消不写数据', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    await tester.tap(find.text('买牛奶'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.moveToSection;
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('move_to_section_sec-buy')), findsNothing);
    expect(await _sectionIdById(repo), {'a': null, 'b': 'sec-buy', 'c': 'sec-daily'});
  });

  testWidgets('#537 没有选中条目时给可见提示，不是静默 no-op', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    commands.value = LifeMenuAction.moveToSection;
    await tester.pumpAndSettle();

    expect(find.text('先选中一条提醒事项'), findsOneWidget);
    expect(find.byKey(const ValueKey('move_to_section_sec-buy')), findsNothing);
    expect(await _sectionIdById(repo), {'a': null, 'b': 'sec-buy', 'c': 'sec-daily'});
  });

  testWidgets('#537 列表没有分区时提示「还没有分区」', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.plain', title: '空白'));
    await repo.upsertItem(const ReminderItem(
      id: 'only',
      listId: 'list.plain',
      title: '唯一一条',
    ));
    final commands = await _pump(tester, repo, listId: 'list.plain');

    await tester.tap(find.text('唯一一条'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.moveToSection;
    await tester.pumpAndSettle();

    expect(find.text('这个列表还没有分区'), findsOneWidget);
    expect(
      (await repo.watchItems().first).firstWhere((e) => e.id == 'only').sectionId,
      isNull,
    );
  });
}
