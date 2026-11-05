// #537 第 1 刀：macOS「显示 → 排序方式」子菜单接线。
//
// 能力本体早就在仓里：ListSortMode 五档 + listSortModeProvider.set()（工具栏「排序 ▾」在用，
// task_scaffold.dart:2220 起）。本卡只补菜单入口，**不新造排序逻辑**，所以判据是
// 「菜单命令真的把列表序换了」——用两档会给出相反行序的数据来量，不看内部字段。
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

/// 两行数据刻意让「按标题」与「按优先级」给出**相反**的行序：
/// aaa 优先级 1、zzz 优先级 5 ⇒ 按标题 = aaa 在上；按优先级（高档在前）= zzz 在上。
Future<InMemoryReminderRepository> _repo() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  await repo.upsertItem(
    const ReminderItem(
      id: 'i-aaa',
      listId: 'list.work',
      title: 'aaa',
      priority: 1,
    ),
  );
  await repo.upsertItem(
    const ReminderItem(
      id: 'i-zzz',
      listId: 'list.work',
      title: 'zzz',
      priority: 5,
    ),
  );
  return repo;
}

bool _aaaAboveZzz(WidgetTester tester) =>
    tester.getTopLeft(find.text('aaa')).dy <
    tester.getTopLeft(find.text('zzz')).dy;

void main() {
  testWidgets('#537 菜单「按标题」把行序换成标题序，且命令被消费', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    // 基线是 manual（仓库契约序 = 插入序），先证此刻 aaa 在上、判据不是恒真。
    expect(_aaaAboveZzz(tester), isTrue, reason: '手动序：aaa 先插入在上');

    commands.value = LifeMenuAction.sortByPriority;
    await tester.pumpAndSettle();
    expect(_aaaAboveZzz(tester), isFalse, reason: '按优先级：zzz(5) 应排到 aaa(1) 上面');
    expect(commands.value, isNull, reason: '消费后必须清空');

    commands.value = LifeMenuAction.sortByTitle;
    await tester.pumpAndSettle();
    expect(_aaaAboveZzz(tester), isTrue, reason: '按标题：aaa 应回到上面');
  });

  testWidgets('#537 菜单「手动」回落仓库契约序，不吃排序档', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    commands.value = LifeMenuAction.sortByPriority;
    await tester.pumpAndSettle();
    expect(_aaaAboveZzz(tester), isFalse);

    commands.value = LifeMenuAction.sortByManual;
    await tester.pumpAndSettle();
    expect(
      _aaaAboveZzz(tester),
      isTrue,
      reason: '手动 = sortOrder asc, id asc = 插入序，与优先级档必须可区分',
    );
  });
}
