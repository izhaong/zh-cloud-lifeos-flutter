// #537 第 8 刀：macOS「文件 → 置顶列表 / 取消置顶列表」。
//
// 置顶态落在视图态键袋的 `pinned:` 命名空间（与子任务显隐同一条已测通路），
// 排序由 `orderListsPinnedFirst` 一处实现，桌面侧栏与紧凑档首页共用它——
// 否则「置顶」只在某一种屏宽生效。智能清单不参与（内置区是固定序）。
//
// 断言分层：① 助手函数的序（纯函数，含「取消后回原序」「智能永不挪位」）；
// ② 键袋读写与既有键共存；③ 菜单命令真的改变了侧栏的**出现顺序**（量行坐标）；
// ④ 智能清单给可见提示而不是静默 no-op。
import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

ReminderList _l(String id, String title, {int order = 0, bool smart = false}) =>
    ReminderList(
      id: id,
      title: title,
      isSmart: smart,
      sortOrder: order,
    );

void main() {
  group('orderListsPinnedFirst', () {
    test('置顶的排到最前，其余保持原序', () {
      final lists = [
        _l('a', '甲', order: 0),
        _l('b', '乙', order: 1),
        _l('c', '丙', order: 2),
      ];
      expect(
        orderListsPinnedFirst(lists, {'pinned:c'}).map((e) => e.id).toList(),
        ['c', 'a', 'b'],
      );
      expect(
        orderListsPinnedFirst(lists, {'pinned:c', 'pinned:b'})
            .map((e) => e.id)
            .toList(),
        ['b', 'c', 'a'],
        reason: '多个置顶之间仍按原 sortOrder 序，不按点击顺序',
      );
    });

    test('取消置顶后回到原序；没有置顶键时返回同一个序', () {
      final lists = [
        _l('a', '甲', order: 0),
        _l('c', '丙', order: 2),
      ];
      final pinned = orderListsPinnedFirst(lists, {'pinned:c'});
      expect(pinned.map((e) => e.id).toList(), ['c', 'a']);
      expect(
        orderListsPinnedFirst(lists, <String>{}).map((e) => e.id).toList(),
        ['a', 'c'],
      );
    });

    test('智能清单不会因为键里混了它就挪位', () {
      final lists = [
        _l('smart.today', '今天', smart: true),
        _l('a', '甲', order: 0),
      ];
      expect(
        orderListsPinnedFirst(lists, {'pinned:smart.today'})
            .map((e) => e.id)
            .toList(),
        ['smart.today', 'a'],
      );
    });
  });

  testWidgets('置顶态写在视图态键袋里，且不冲掉别的键', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    final container = ProviderContainer(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(collapsedKeysProvider.notifier);
    notifier.toggle('list.a|收件箱');
    notifier.setListPinned('list.a', true);
    expect(
      container.read(collapsedKeysProvider),
      containsAll(<String>['list.a|收件箱', 'pinned:list.a']),
    );

    notifier.setListPinned('list.a', false);
    expect(container.read(collapsedKeysProvider), {'list.a|收件箱'},
        reason: '取消置顶只删自己那条键');
  });

  Future<ValueNotifier<LifeMenuAction?>> pumpThreePane(
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
        child: lifeTestHost(const TaskScaffold(openListId: 'list.c')),
      ),
    );
    await tester.pumpAndSettle();
    return commands;
  }

  List<String> sidebarOrder(WidgetTester tester) {
    final rows = <String, double>{};
    for (final id in ['list.a', 'list.b', 'list.c']) {
      final finder = find.byKey(ValueKey('my_list_$id'));
      if (finder.evaluate().isNotEmpty) {
        rows[id] = tester.getTopLeft(finder).dy;
      }
    }
    final entries = rows.entries.toList()
      ..sort((x, y) => x.value.compareTo(y.value));
    return entries.map((e) => e.key).toList();
  }

  testWidgets('#537 菜单「置顶列表」把前台列表排到侧栏最前，取消后回原序',
      (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(_l('list.a', '甲', order: 0));
    await repo.upsertList(_l('list.b', '乙', order: 1));
    await repo.upsertList(_l('list.c', '丙', order: 2));
    final commands = await pumpThreePane(tester, repo);

    expect(sidebarOrder(tester), ['list.a', 'list.b', 'list.c'],
        reason: '默认按 sortOrder 升序');

    commands.value = LifeMenuAction.pinList;
    await tester.pumpAndSettle();
    expect(commands.value, isNull, reason: '命令消费后必须清空');
    expect(sidebarOrder(tester), ['list.c', 'list.a', 'list.b']);

    commands.value = LifeMenuAction.unpinList;
    await tester.pumpAndSettle();
    expect(sidebarOrder(tester), ['list.a', 'list.b', 'list.c'],
        reason: '取消置顶要回到 sortOrder 原序');

    // 置顶是视图态：列表数据本身不该被改写
    final lists = await repo.watchLists().first;
    expect(
      lists.firstWhere((e) => e.id == 'list.c').sortOrder,
      2,
      reason: '不得把置顶落成改 sortOrder',
    );
  });

  testWidgets('#537 智能清单里按「置顶列表」给可见提示，且不写视图态键',
      (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(_l('list.a', '甲', order: 0));
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final commands = ValueNotifier<LifeMenuAction?>(null);
    addTearDown(commands.dispose);
    final container = ProviderContainer(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        lifeMenuCommandsProvider.overrideWithValue(commands),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(const TaskScaffold(openListId: 'smart.today')),
      ),
    );
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.pinList;
    await tester.pumpAndSettle();

    expect(find.text('智能清单不用置顶'), findsOneWidget);
    expect(
      container.read(collapsedKeysProvider).where((k) => k.startsWith('pinned:')),
      isEmpty,
      reason: '提示归提示，不该往键袋里落一条置顶键',
    );
  });

  testWidgets('#537 紧凑档首页用同一条置顶序（不是只在桌面生效）', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(_l('list.a', '甲', order: 0));
    await repo.upsertList(_l('list.b', '乙', order: 1));
    await repo.upsertList(_l('list.c', '丙', order: 2));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // openListId 为空 = 紧凑档首页（_CompactPane），「我的列表」按 mine 渲染
        child: lifeTestHost(const TaskScaffold()),
      ),
    );
    await tester.pumpAndSettle();

    List<String> order(List<String> titles) {
      final positioned = <String, double>{};
      for (final t in titles) {
        final f = find.text(t);
        if (f.evaluate().isNotEmpty) positioned[t] = tester.getTopLeft(f).dy;
      }
      final entries = positioned.entries.toList()
        ..sort((x, y) => x.value.compareTo(y.value));
      return entries.map((e) => e.key).toList();
    }

    expect(order(['甲', '乙', '丙']), ['甲', '乙', '丙']);

    container.read(collapsedKeysProvider.notifier).setListPinned('list.c', true);
    await tester.pumpAndSettle();

    expect(order(['甲', '乙', '丙']), ['丙', '甲', '乙'],
        reason: '侧栏改了序而首页没跟着改，就是「置顶只在某档宽生效」的缺陷');
  });
}
