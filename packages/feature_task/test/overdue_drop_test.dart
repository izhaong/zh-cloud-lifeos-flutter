// #545：拖进「已过期」分区头到底改不改 dueAt。
//
// 修复前：_onSectionDrop 的注释写着「已过期=不变」，而 _sectionTime 对不在白名单
// 里的档名一律走 `_ => today`，于是拖一次就把今晚 20:00 写成今天 00:00。
// 修复后：_onSectionDrop 先按 _timeSectionBuckets 卡档名，非时间档不落库。
//
// 测法说明（重要）：先前用手势模拟拖放（startGesture + moveBy + moveTo）没能跨过
// Draggable 的起手阈值，拖放没落进 DragTarget，于是「不变」那条绿是**假绿**
// （反向对照判红才暴露它，Expected 09:00 / Actual 20:00）。现在改成从 widget 树里
// 取出真实的 DragTarget 实例、调用它挂着的 onAcceptWithDetails 闭包 —— 走的是生产
// 代码同一条回调，只是绕开手势模拟；Draggable 起手那一段的缺陷另单追。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 29, 9, 30);

Future<InMemoryReminderRepository> _seed() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  // 09:00 < 挂钟 09:30 → 落「已过期」；10:00 → 「上午」；20:00 → 「今晚」。
  await repo.upsertItem(
    ReminderItem(
      id: 'i-over',
      listId: 'list.work',
      title: '过期的电话',
      dueAt: DateTime(2026, 10, 29, 9),
    ),
  );
  await repo.upsertItem(
    ReminderItem(
      id: 'i-am',
      listId: 'list.work',
      title: '上午的电话',
      dueAt: DateTime(2026, 10, 29, 10),
    ),
  );
  await repo.upsertItem(
    ReminderItem(
      id: 'i-eve',
      listId: 'list.work',
      title: '今晚的跑步',
      dueAt: DateTime(2026, 10, 29, 20),
    ),
  );
  return repo;
}

Future<DateTime?> _dueOf(ReminderRepository repo, String id) async {
  final items = await repo.watchItems(listId: 'list.work').first;
  return items.firstWhere((e) => e.id == id).dueAt;
}

Future<void> _pumpToday(
  WidgetTester tester,
  InMemoryReminderRepository repo,
) async {
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
      child: const MaterialApp(home: TaskScaffold(openListId: 'smart.today')),
    ),
  );
  await tester.pumpAndSettle();
}

/// 把 itemId 落到 sectionKey 那个分区头上：调用生产代码挂在 DragTarget 上的闭包。
Future<void> _dropOnSection(
  WidgetTester tester, {
  required String itemId,
  required String sectionKey,
}) async {
  final finder = find.byKey(ValueKey('drag_target_$sectionKey'));
  expect(finder, findsOneWidget, reason: '分区头drag_target_$sectionKey 要在');
  final target = tester.widget<DragTarget<String>>(finder);
  final onAccept = target.onAcceptWithDetails;
  expect(onAccept, isNotNull, reason: '该分区头确实挂了「接受拖入」的回调');
  onAccept!(
    DragTargetDetails<String>(data: itemId, offset: tester.getCenter(finder)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('#545 对照：落到「上午」确实改 dueAt（证明这条测法能落）', (tester) async {
    final repo = await _seed();
    await _pumpToday(tester, repo);
    expect(
      await _dueOf(repo, 'i-eve'),
      DateTime(2026, 10, 29, 20),
      reason: '起手前是今晚 20:00',
    );

    await _dropOnSection(tester, itemId: 'i-eve', sectionKey: '上午');

    expect(
      await _dueOf(repo, 'i-eve'),
      DateTime(2026, 10, 29, 9),
      reason: '这条不过 ⇒ 测法没走通，下面的结论不作数',
    );
  });

  testWidgets('#545 落到「已过期」到底改不改 dueAt', (tester) async {
    final repo = await _seed();
    await _pumpToday(tester, repo);
    expect(find.text('过期的电话'), findsOneWidget, reason: '种子确实落了已过期档');

    await _dropOnSection(tester, itemId: 'i-eve', sectionKey: '已过期');

    expect(
      await _dueOf(repo, 'i-eve'),
      DateTime(2026, 10, 29, 20),
      reason: '按注释口径：「已过期」不是时间档，落进去不该把今晚改成今天',
    );
    expect(
      await _dueOf(repo, 'i-over'),
      DateTime(2026, 10, 29, 9),
      reason: '本来就在已过期档的那条也不该被动到',
    );
  });
}
