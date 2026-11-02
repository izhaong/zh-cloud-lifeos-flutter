// #548：今天视图拖拽反馈在 Overlay 里宽度无界，起手即抛 RenderFlex 断言。
//
// 修复前：`Draggable.feedback` 直接复用列表里那一条行组件（标题用 `Expanded`），
// 而 Overlay 给反馈层的宽度约束是 `0.0<=w<=Infinity` —— 起手那一刻
// `performLayout` 就抛「RenderFlex children have non-zero flex but incoming
// width constraints are unbounded」，与目标分区、与落库结果都无关。
//
// 修复后：反馈层用 LayoutBuilder 拿到的**源行实际宽度**包一层 SizedBox，
// Expanded 重新有界 → 起手不抛，且跟手卡片与源行同宽。
//
// 顺带把一条因果链钉住：起手抛的这个断言会打断拖拽会话，所以 #545 当时用手势模拟
// 拖放从未落进 DragTarget（「不变」那条绿因此是假绿，只能改走回调层）。最后一条
// 用例在修复后用真实指针把「拖到上午 → 落 09:00」补成手势级覆盖。
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

Future<void> _pumpToday(
  WidgetTester tester,
  InMemoryReminderRepository repo, {
  Size viewport = const Size(1280, 900),
}) async {
  tester.view.physicalSize = viewport;
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

/// 起手并拖出一段距离（这就是「拖拽反馈出现在 Overlay 里」的那一刻）。
Future<void> _startDrag(WidgetTester tester, String id) async {
  final drag = find.byKey(ValueKey('draggable_$id'));
  expect(drag, findsOneWidget, reason: '可拖的行在：draggable_$id');
  final gesture = await tester.startGesture(tester.getCenter(drag));
  await gesture.moveBy(const Offset(0, 40));
  await tester.pump();
  addTearDown(gesture.removePointer);
}

void main() {
  testWidgets('#548 起手不抛渲染断言（1280 三栏）', (tester) async {
    final repo = await _seed();
    await _pumpToday(tester, repo);
    final before = tester.takeException();
    expect(before, isNull, reason: '起手前本来就干净（这条判据的阴性对照）');

    await _startDrag(tester, 'i-eve');

    final err = tester.takeException();
    expect(
      err,
      isNull,
      reason:
          '拖拽反馈进了 Overlay 就不该把行里的 Expanded 打成无界'
          '\n实际抛的是：$err',
    );
  });

  testWidgets('#548 跟手卡片与源行同宽（1280 三栏）', (tester) async {
    final repo = await _seed();
    await _pumpToday(tester, repo);
    final sourceWidth = tester
        .getSize(find.byKey(const ValueKey('draggable_i-eve')))
        .width;
    expect(sourceWidth, greaterThan(0), reason: '源行起手前有宽度');

    await _startDrag(tester, 'i-eve');
    tester.takeException();

    final feedback = find.byKey(const ValueKey('drag_feedback_i-eve'));
    expect(feedback, findsOneWidget, reason: '反馈层要能被量到（带 key）');
    expect(
      tester.getSize(feedback).width,
      sourceWidth,
      reason: '跟手卡片应当与源行同宽，而不是无界或塌陷',
    );
    expect(
      find.descendant(of: feedback, matching: find.text('今晚的跑步')),
      findsOneWidget,
      reason: '跟手卡片画的还得是那一条本身——只补宽度、把内容换成空盒子不算修好',
    );
  });

  testWidgets('#548 紧凑档（390）起手同样不抛', (tester) async {
    final repo = await _seed();
    await _pumpToday(tester, repo, viewport: const Size(390, 844));
    final drag = find.byKey(const ValueKey('draggable_i-eve'));
    if (drag.evaluate().isEmpty) {
      // 紧凑档若压根不铺可拖行，这条就没有可量的表面 —— 判红而不是静默跳过，
      // 免得哪天布局变了、这里悄悄变成恒真。
      fail(
        '390 档没有渲染 draggable_i-eve：本用例的前提不成立，'
        '请改测法或删掉这条，别让它空转',
      );
    }
    await _startDrag(tester, 'i-eve');
    expect(tester.takeException(), isNull, reason: '窄屏同样不该抛');
  });

  // #548 修好之后才打得开的一条：起手时的渲染断言会打断拖拽会话，所以 #545
  // 当时用手势模拟「拖进上午」从未落进 DragTarget（绿是假绿，只能改走回调层）。
  // 这条把那条残留面补成**真实指针路径**的覆盖。
  testWidgets('#548 手势级拖放能落进 DragTarget（补 #545 的残留面）', (tester) async {
    final repo = await _seed();
    await _pumpToday(tester, repo);
    final from = tester.getCenter(
      find.byKey(const ValueKey('draggable_i-eve')),
    );
    final target = find.byKey(const ValueKey('drag_target_上午'));
    expect(target, findsOneWidget, reason: '「上午」分区头要在（种子 i-am 撑起它）');
    final to = tester.getCenter(target);

    final gesture = await tester.startGesture(from);
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull, reason: '起手不抛，拖拽会话才不会被中断');
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull, reason: '移到目标头上仍不抛');
    await gesture.up();
    await tester.pumpAndSettle();

    final items = await repo.watchItems(listId: 'list.work').first;
    expect(
      items.firstWhere((e) => e.id == 'i-eve').dueAt,
      DateTime(2026, 10, 29, 9),
      reason: '真实指针拖到「上午」应当落 09:00；仍是 20:00 就说明拖没落地',
    );
  });
}
