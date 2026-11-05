// #487 面②：「计划」视图每个日期组末尾要有 Apple 那条**空圆圈快捷创建行**。
// Apple 实测（guide zh-cn/12「Add reminders to a section: Add reminders at the bottom
// of the section」）：组末一行只有空心圆，点它即在**那一天**新建。
// develop@07d1eab 上：面①的三档骨架已在 #527 落地（逐日→本月剩余→逐月），
// 但组末一行仍缺——快捷新建只有今天视图的组头「＋」（#513），计划视图一条都没有。
// 月档（「十一月其他时间」「十二月」「2027年一月」）不定位到具体一天 ⇒ 不出这一行；
// 「已过期」按 #513 面② 口径不提供新建；搜索态按 #531 口径只出命中结果。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

final _now = DateTime(2026, 11, 2, 9); // 周一

/// 组末快捷行的键（不以 `section_` 起头，免得被骨架档位断言的采集器一起数走）。
List<String> _quickCreateKeys(WidgetTester tester) {
  final out = <String>[];
  void walk(Element e) {
    final k = e.widget.key;
    if (k is ValueKey<String> && k.value.startsWith('quick_create_')) {
      out.add(k.value.substring('quick_create_'.length));
    }
    e.visitChildren(walk);
  }

  walk(tester.binding.rootElement!);
  return out;
}

Future<void> _pump(
  WidgetTester tester,
  InMemoryReminderRepository repo, {
  String listId = 'smart.scheduled',
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  repo.nowProvider = () => _now;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: lifeTestHost(TaskScaffold(openListId: listId)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<InMemoryReminderRepository> _repo() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  return repo;
}

void main() {
  testWidgets('#487 组末快捷行只落在「具体一天」的组，月档一天都没有', (tester) async {
    final repo = await _repo();
    // 有条目的一天（11/20）+ 零条目的逐日骨架一天（11/5），两档都要出这一行。
    await repo.upsertItem(
      ReminderItem(
        id: 'i-nov20',
        listId: 'list.work',
        title: '月中项',
        dueAt: DateTime(2026, 11, 20, 9),
      ),
    );
    await _pump(tester, repo);

    final keys = _quickCreateKeys(tester);
    expect(
      keys,
      containsAll(<String>['11月20日 周五', '11月5日 周四']),
      reason: '有条目的日期组与逐日骨架组都要有组末快捷行',
    );
    expect(keys, isNot(contains('十一月其他时间')), reason: '月档不定位到具体一天');
    expect(keys, isNot(contains('十二月')));
    expect(keys, isNot(contains('2027年一月')));
    expect(keys, isNot(contains('已过期')), reason: '#513 面②：已过期不提供新建');
  });

  testWidgets('#487 点空圆圈即在「那一天」新建：条目落库且归进同一天组头', (tester) async {
    final repo = await _repo();
    // 计划视图整表零条目时走空态引导（不渲染分区），故种一条把列表体撑起来；
    // 种在 11/3，被测的 11/5 保持**零条目**——正是要验证骨架组也有这一行。
    await repo.upsertItem(
      ReminderItem(
        id: 'i-nov3',
        listId: 'list.work',
        title: '明天项',
        dueAt: DateTime(2026, 11, 3, 8),
      ),
    );
    await _pump(tester, repo);

    // 「11月5日 周四」这天本来零条目，只有骨架头。
    expect(find.byKey(const ValueKey('quick_create_11月5日 周四')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quick_create_11月5日 周四')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('draft_field')), '周四项');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final items = await repo.watchItems().first;
    final created = items.firstWhere((e) => e.title == '周四项');
    expect(
      created.dueAt,
      DateTime(2026, 11, 5),
      reason: 'Apple 快捷新建不带时刻：就是那一天的 00:00，不能落到今天',
    );

    // 归组：仍挂在原组头下，不因新建多出一个裸「11月5日」组（#526 不变量）。
    final sectionKeys = <String>[];
    void walk(Element e) {
      final k = e.widget.key;
      if (k is ValueKey<String> && k.value.startsWith('section_')) {
        sectionKeys.add(k.value.substring('section_'.length));
      }
      e.visitChildren(walk);
    }

    walk(tester.binding.rootElement!);
    expect(sectionKeys, contains('11月5日 周四'), reason: '条目进原组头');
    expect(sectionKeys, isNot(contains('11月5日')), reason: '不得多出一个不带后缀的同日组头');

    // 快捷落点是一次性的：随后走普通幽灵行新建，必须回到「今天」，
    // 不能静默继承上一次那个 11月5日。
    await tester.tap(find.byKey(const ValueKey('ghost_new_item')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('draft_field')), '普通项');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final after = await repo.watchItems().first;
    expect(
      after.firstWhere((e) => e.title == '普通项').dueAt,
      DateTime(2026, 11, 2),
      reason: '组末圆圈的落点不得泄漏给下一次普通新建',
    );
  });

  testWidgets('#487 搜索态不出组末快捷行（与 #531 同口径）', (tester) async {
    final repo = await _repo();
    await repo.upsertItem(
      ReminderItem(
        id: 'i-nov20',
        listId: 'list.work',
        title: 'REG2 月中项',
        dueAt: DateTime(2026, 11, 20, 9),
      ),
    );
    await _pump(tester, repo);
    expect(
      _quickCreateKeys(tester),
      contains('11月20日 周五'),
      reason: '空闲态先证行确实存在',
    );

    await tester.enterText(
      find.byKey(const ValueKey('toolbar_search')),
      'REG2',
    );
    await tester.pumpAndSettle();
    expect(_quickCreateKeys(tester), isEmpty, reason: '搜索态只出命中结果，不铺新建入口');
  });

  testWidgets('#487 反向对照：今天视图不因本卡多出组末行（仍走 #513 组头「＋」）', (tester) async {
    final repo = await _repo();
    await repo.upsertItem(
      ReminderItem(
        id: 'i-today',
        listId: 'list.work',
        title: '今天项',
        dueAt: DateTime(2026, 11, 2, 10),
      ),
    );
    await _pump(tester, repo, listId: 'smart.today');

    expect(
      _quickCreateKeys(tester),
      isEmpty,
      reason: '今天视图的快捷新建在组头「＋」（#513），本卡只补计划视图',
    );
  });
}
