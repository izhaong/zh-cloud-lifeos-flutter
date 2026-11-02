// #537 第 8 刀：macOS「文件 → 置顶列表 / 取消置顶列表」。
// #563 把落点从视图态键袋改成清单实体的 `isPinned`：置顶从此会落库、会随同步
// 通道走，换设备还在；`pinned:<id>` 那条本地键不再是任何人的真相源。
//
// 排序由 `orderListsPinnedFirst` 一处实现，桌面侧栏与紧凑档首页共用它——
// 否则「置顶」只在某一种屏宽生效。智能清单不参与（内置区是固定序）。
//
// 断言分层：① 助手函数的序（纯函数，含「取消后回原序」「智能永不挪位」）；
// ② 置顶态经仓库往返（实体字段，不是内存对象改一下就完事）；
// ③ 菜单命令真的改变了侧栏的**出现顺序**（量行坐标）；
// ④ 智能清单给可见提示而不是静默 no-op；⑤ 出站/入站同步载荷都带这个字段。
import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

ReminderList _l(
  String id,
  String title, {
  int order = 0,
  bool smart = false,
  bool pinned = false,
}) => ReminderList(
  id: id,
  title: title,
  isSmart: smart,
  sortOrder: order,
  isPinned: pinned,
);

/// 当前挂在非智能清单上的置顶 id（置顶改成实体字段后的唯一真相源）。
Future<Set<String>> _pinnedIds(InMemoryReminderRepository repo) async =>
    (await repo.watchLists().first)
        .where((e) => !e.isSmart && e.isPinned)
        .map((e) => e.id)
        .toSet();

void main() {
  group('orderListsPinnedFirst', () {
    test('置顶的排到最前，其余保持原序', () {
      final lists = [
        _l('a', '甲', order: 0),
        _l('b', '乙', order: 1),
        _l('c', '丙', order: 2, pinned: true),
      ];
      expect(orderListsPinnedFirst(lists).map((e) => e.id).toList(), [
        'c',
        'a',
        'b',
      ]);
      expect(
        orderListsPinnedFirst([
          _l('a', '甲', order: 0),
          _l('b', '乙', order: 1, pinned: true),
          _l('c', '丙', order: 2, pinned: true),
        ]).map((e) => e.id).toList(),
        ['b', 'c', 'a'],
        reason: '多个置顶之间仍按原 sortOrder 序，不按点击顺序',
      );
    });

    test('取消置顶后回到原序；没有置顶时原样返回', () {
      final lists = [
        _l('a', '甲', order: 0),
        _l('c', '丙', order: 2, pinned: true),
      ];
      expect(orderListsPinnedFirst(lists).map((e) => e.id).toList(), [
        'c',
        'a',
      ]);
      expect(
        orderListsPinnedFirst([
          _l('a', '甲', order: 0),
          _l('c', '丙', order: 2),
        ]).map((e) => e.id).toList(),
        ['a', 'c'],
      );
    });

    test('智能清单即使带着 isPinned 也不挪位', () {
      final lists = [
        _l('smart.today', '今天', smart: true, pinned: true),
        _l('a', '甲', order: 0),
      ];
      expect(orderListsPinnedFirst(lists).map((e) => e.id).toList(), [
        'smart.today',
        'a',
      ], reason: '脏数据（智能清单被置了顶）也不能把内置区打乱');
    });
  });

  test('#563 置顶态是实体字段：经仓库往返写得进读得回', () async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(_l('list.a', '甲', order: 0));
    expect(await _pinnedIds(repo), isEmpty, reason: '默认不置顶');

    final before = (await repo.watchLists().first).firstWhere(
      (e) => e.id == 'list.a',
    );
    await repo.upsertList(before.copyWith(isPinned: true));

    expect(await _pinnedIds(repo), {'list.a'});
    expect(
      before.isPinned,
      isFalse,
      reason: 'ReminderList 是不可变值对象，upsert 不得回头改调用方手里那份',
    );
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

  testWidgets('#537 菜单「置顶列表」把前台列表排到侧栏最前，取消后回原序', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(_l('list.a', '甲', order: 0));
    await repo.upsertList(_l('list.b', '乙', order: 1));
    await repo.upsertList(_l('list.c', '丙', order: 2));
    final commands = await pumpThreePane(tester, repo);

    expect(sidebarOrder(tester), [
      'list.a',
      'list.b',
      'list.c',
    ], reason: '默认按 sortOrder 升序');

    commands.value = LifeMenuAction.pinList;
    await tester.pumpAndSettle();
    expect(commands.value, isNull, reason: '命令消费后必须清空');
    expect(sidebarOrder(tester), ['list.c', 'list.a', 'list.b']);
    expect(await _pinnedIds(repo), {
      'list.c',
    }, reason: '#563：置顶要落在实体上，不然同步不出去、换设备就掉');

    commands.value = LifeMenuAction.unpinList;
    await tester.pumpAndSettle();
    expect(sidebarOrder(tester), [
      'list.a',
      'list.b',
      'list.c',
    ], reason: '取消置顶要回到 sortOrder 原序');
    expect(await _pinnedIds(repo), isEmpty);

    final lists = await repo.watchLists().first;
    expect(
      lists.firstWhere((e) => e.id == 'list.c').sortOrder,
      2,
      reason: '不得把置顶落成改 sortOrder',
    );
  });

  testWidgets('#537 智能清单里按「置顶列表」给可见提示，且不写脏数据', (tester) async {
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
      (await repo.watchLists().first).where((e) => e.isPinned),
      isEmpty,
      reason: '提示归提示，不该把任何清单的 isPinned 写成 true',
    );
    expect(
      container
          .read(collapsedKeysProvider)
          .where((k) => k.startsWith('pinned:')),
      isEmpty,
      reason: '#563：置顶已改走实体字段，键袋里不该再出现 pinned: 命名空间',
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

    final c = (await repo.watchLists().first).firstWhere(
      (e) => e.id == 'list.c',
    );
    await repo.upsertList(c.copyWith(isPinned: true));
    await tester.pumpAndSettle();

    expect(order(['甲', '乙', '丙']), [
      '丙',
      '甲',
      '乙',
    ], reason: '侧栏改了序而首页没跟着改，就是「置顶只在某档宽生效」的缺陷');
  });

  test('#563 同步载荷双向都带 isPinned（服务端 lifeos_list.is_pinned 的契约）', () {
    final payload = listSyncPayload(_l('list.c', '丙', order: 2, pinned: true));
    expect(payload['isPinned'], isTrue, reason: '不发出去的话服务端那一列永远是默认值');
    final back = reminderListFromSyncPayload(payload, entityId: 'srv-9');
    expect(back.isPinned, isTrue, reason: '入站要还原，否则拉回来就丢置顶');
    final neutral = reminderListFromSyncPayload(
      {'name': '丙'},
      entityId: 'srv-9',
      existing: _l('list.c', '丙', pinned: true),
    );
    expect(neutral.isPinned, isTrue, reason: '服务端是部分更新语义：缺键=保持');
  });
}
