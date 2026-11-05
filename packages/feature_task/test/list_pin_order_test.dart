// #537 第 8 刀：macOS「文件 → 置顶列表 / 取消置顶列表」。
// #563 把落点从视图态键袋改成清单实体的 `isPinned`：置顶从此会落库、会随同步
// 通道走，换设备还在；`pinned:<id>` 那条本地键不再是任何人的真相源。
//
// 置顶的落点由 `splitPinnedUserLists` 一处实现，桌面侧栏与紧凑档首页共用它——
// 否则「置顶」只在某一种屏宽生效。智能清单不参与（内置区是固定序）。
// #588 改的是**位置**：置顶的自有清单不再留在「我的列表」里排到首行，
// 而是离开该节、与智能清单同排占一张卡（Apple 的呈现）。
//
// 断言分层：① 助手函数的分流（纯函数，含「取消后回原序」「智能永不挪位」）；
// ② 置顶态经仓库往返（实体字段，不是内存对象改一下就完事）；
// ③ 菜单命令真的改变了侧栏的**呈现位置**（量卡片与行的坐标，不量文案）；
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
  group('splitPinnedUserLists', () {
    test('置顶的交给卡片区，其余留在「我的列表」且保持原序', () {
      final s = splitPinnedUserLists([
        _l('a', '甲', order: 0),
        _l('b', '乙', order: 1),
        _l('c', '丙', order: 2, pinned: true),
      ]);
      expect(s.cards.map((e) => e.id).toList(), ['c']);
      expect(
        s.mine.map((e) => e.id).toList(),
        ['a', 'b'],
        reason: '#588：置顶的清单不得再留在「我的列表」里——哪怕排在最前也不对',
      );

      final two = splitPinnedUserLists([
        _l('a', '甲', order: 0),
        _l('b', '乙', order: 1, pinned: true),
        _l('c', '丙', order: 2, pinned: true),
      ]);
      expect(
        two.cards.map((e) => e.id).toList(),
        ['b', 'c'],
        reason: '多个置顶之间仍按原 sortOrder 序，不按点击顺序',
      );
      expect(two.mine.map((e) => e.id).toList(), ['a']);
    });

    test('取消置顶后回到「我的列表」原序；没有置顶时卡片区不额外加卡', () {
      expect(
        splitPinnedUserLists([
          _l('a', '甲', order: 0),
          _l('c', '丙', order: 2),
        ]).cards,
        isEmpty,
      );
      final unpinned = splitPinnedUserLists([
        _l('a', '甲', order: 0),
        _l('b', '乙', order: 1),
        _l('c', '丙', order: 2),
      ]);
      expect(unpinned.mine.map((e) => e.id).toList(), ['a', 'b', 'c'],
          reason: '#588 判据：取消置顶要落回原序（sort_order 没被改过）');
    });

    test('智能清单即使带着 isPinned 也不进卡片区', () {
      final s = splitPinnedUserLists([
        _l('smart.today', '今天', smart: true, pinned: true),
        _l('a', '甲', order: 0),
      ]);
      expect(
        s.cards,
        isEmpty,
        reason: '脏数据（智能清单被置了顶）也不能把内置卡片区打乱',
      );
      expect(s.mine.map((e) => e.id).toList(), ['smart.today', 'a']);
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

  testWidgets('#588 菜单「置顶列表」让清单离开「我的列表」、进顶部卡片区，取消后回原序', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(_l('list.a', '甲', order: 0));
    await repo.upsertList(_l('list.b', '乙', order: 1));
    await repo.upsertList(_l('list.c', '丙', order: 2));
    final commands = await pumpThreePane(tester, repo);

    expect(sidebarOrder(tester), [
      'list.a',
      'list.b',
      'list.c',
    ], reason: '默认按 sortOrder 升序，全都在「我的列表」');

    commands.value = LifeMenuAction.pinList;
    await tester.pumpAndSettle();
    expect(commands.value, isNull, reason: '命令消费后必须清空');
    expect(await _pinnedIds(repo), {
      'list.c',
    }, reason: '#563：置顶要落在实体上，不然同步不出去、换设备就掉');

    // #588 判据（Apple 呈现）：置顶后这一行从「我的列表」消失，
    // 顶部卡片区多一张同名卡；两半都要量，缺一半就是没改到位。
    expect(
      find.byKey(const ValueKey('my_list_list.c')),
      findsNothing,
      reason: '置顶的清单不得再留在「我的列表」里',
    );
    final card = find.byKey(const ValueKey('smart_card_list.c'));
    expect(card, findsOneWidget, reason: '卡片区必须真的出现这张清单，找不到就等于没取证');
    expect(
      tester.getTopLeft(card).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('my_list_list.a'))).dy),
      reason: '#588 判据 ①：卡片要在「我的列表」首行之上（量坐标，不量文案存在）',
    );
    expect(sidebarOrder(tester), ['list.a', 'list.b']);

    commands.value = LifeMenuAction.unpinList;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('smart_card_list.c')), findsNothing);
    expect(sidebarOrder(tester), [
      'list.a',
      'list.b',
      'list.c',
    ], reason: '#588 判据 ③：取消置顶要落回「我的列表」原序');
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

  testWidgets('#588 紧凑档首页用同一条分流（不是只在桌面生效）', (tester) async {
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
    expect(find.byKey(const ValueKey('home_list_list.c')), findsOneWidget);

    final c = (await repo.watchLists().first).firstWhere(
      (e) => e.id == 'list.c',
    );
    await repo.upsertList(c.copyWith(isPinned: true));
    await tester.pumpAndSettle();

    // #588：紧凑档首页与桌面侧栏走同一条分流——行消失、卡出现。
    // 只量文案顺序会被卡片里同名的标题满足，所以两句都按结构句柄量。
    expect(
      find.byKey(const ValueKey('home_list_list.c')),
      findsNothing,
      reason: '紧凑档里置顶的清单也该离开「我的列表」',
    );
    expect(
      find.byKey(const ValueKey('smart_card_list.c')),
      findsOneWidget,
      reason: '侧栏改了呈现而首页没跟着改，就是「置顶只在某档宽生效」的缺陷',
    );
    expect(order(['甲', '乙', '丙']), [
      '丙',
      '甲',
      '乙',
    ], reason: '卡片在「我的列表」之上，文案序仍应反映置顶在前');
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
