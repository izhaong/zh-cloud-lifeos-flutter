// #486 一面：macOS 菜单「文件 → 新建分区 / 编辑分区…」必须有接收方。
//
// 入口本体在 #533 已经落地（⋯ 菜单里的 showNewSectionDialog / showSectionEditorSheet），
// 本卡只补菜单栏这条接线：菜单项走 LifeMenuAction 命令总线（app_core），
// 由 TaskScaffold 消费后调同一对入口——**不能**在菜单侧另写一套新建逻辑。
// 反向对照守的是 #533 那条闸门：智能清单没有分区，菜单命令也不该弹出对话框。
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
  return repo;
}

Future<List<ReminderSection>> _sectionsOf(ReminderRepository repo) async {
  final lists = await repo.watchLists().first;
  return lists.firstWhere((e) => e.id == 'list.work').sections;
}

void main() {
  testWidgets('#486 菜单「新建分区」打开新建弹层，提交后分区落库', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    expect(find.byKey(const ValueKey('new_section_name')), findsNothing);

    commands.value = LifeMenuAction.newSection;
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('new_section_name')),
      findsOneWidget,
      reason: '菜单命令应打开与 ⋯ 菜单同一个新建分区弹层',
    );
    expect(commands.value, isNull, reason: '消费后必须清空（否则重建时重复弹）');

    await tester.enterText(
      find.byKey(const ValueKey('new_section_name')),
      '菜单建的分区',
    );
    await tester.tap(find.byKey(const ValueKey('new_section_submit')));
    await tester.pumpAndSettle();

    final sections = await _sectionsOf(repo).then((v) => v);
    expect(sections.map((e) => e.title).toList(), contains('菜单建的分区'));
  });

  testWidgets('#486 菜单「编辑分区…」打开编辑面板（含已有分区行）', (tester) async {
    final repo = await _repo();
    await repo.upsertSection(
      listId: 'list.work',
      section: const ReminderSection(id: 'sec-1', title: '已有分区', sortOrder: 1),
    );
    final commands = await _pump(tester, repo);

    commands.value = LifeMenuAction.editSections;
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('section_editor_done')),
      findsOneWidget,
      reason: '应打开 #533 的编辑分区面板',
    );
    expect(find.byKey(const ValueKey('section_row_sec-1')), findsOneWidget);
    expect(commands.value, isNull);
  });

  testWidgets('#486 反向对照：智能清单没有分区，菜单命令不弹层', (tester) async {
    final repo = await _repo();
    await repo.upsertItem(
      const ReminderItem(id: 'i-1', listId: 'list.work', title: '今天项'),
    );
    final commands = await _pump(tester, repo, listId: 'smart.today');

    commands.value = LifeMenuAction.newSection;
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('new_section_name')),
      findsNothing,
      reason: '#533 定的闸门：sectionsEnabled = !list.isSmart，菜单侧不得绕过',
    );

    commands.value = LifeMenuAction.editSections;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('section_editor_done')), findsNothing);
  });
}
