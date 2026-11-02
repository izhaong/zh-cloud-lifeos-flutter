// #537 第 2 刀：macOS「文件 → 编辑列表」接线。
//
// 编辑列表的弹层本体早就在仓里（showEditListDialog：改名/颜色/类型，侧栏 ⋯ 那条路径在用），
// 本刀只把它接到菜单命令上——并且编辑的是**当前打开的那个列表**（Apple 语义：
// 文件菜单作用在前台清单上），不在菜单里再做一个选单列表的二级选择器。
// 反向对照守的是与 #533/#486 同一闸门：智能清单没有「编辑列表」可言。
import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

Future<ValueNotifier<LifeMenuAction?>> _pump(
  WidgetTester tester,
  ReminderRepository repo, {
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
    id: 'i-1',
    listId: 'list.work',
    title: '买牛奶',
  ));
  return repo;
}

Future<ReminderList> _listOf(ReminderRepository repo) async {
  final lists = await repo.watchLists().first;
  return lists.firstWhere((e) => e.id == 'list.work');
}

void main() {
  testWidgets('#537 菜单「编辑列表」开当前清单的编辑弹层，保存后落库', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    expect(find.byKey(const ValueKey('edit_list_name')), findsNothing);

    commands.value = LifeMenuAction.editList;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit_list_name')), findsOneWidget,
        reason: '应与侧栏 ⋯ 打开同一个编辑弹层，不是第二套实现');
    // 不直接引 CupertinoTextField 类型（feature_task 的测试面没有 cupertino_ui 依赖，
    // 硬加依赖只为一个断言不值），改读它内部的 EditableText 控制器。
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('edit_list_name')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.controller.text, '工作',
        reason: '编辑的是当前打开的清单，不是随便挑一个');
    expect(commands.value, isNull, reason: '消费后必须清空');

    await tester.enterText(
      find.byKey(const ValueKey('edit_list_name')),
      '改名后的工作',
    );
    await tester.tap(find.byKey(const ValueKey('edit_list_submit')));
    await tester.pumpAndSettle();

    expect((await _listOf(repo)).title, '改名后的工作');
  });

  testWidgets('#537 反向对照：智能清单没有「编辑列表」', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo, listId: 'smart.today');

    commands.value = LifeMenuAction.editList;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit_list_name')), findsNothing,
        reason: '智能清单不可编辑（与 #533 分区闸门同口径）');
    expect((await _listOf(repo)).title, '工作', reason: '更不该顺手改到别的清单');
  });
}
