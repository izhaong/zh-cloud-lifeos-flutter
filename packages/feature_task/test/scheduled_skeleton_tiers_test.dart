// #527（#487 第二面）：计划视图的骨架档位。
// Apple 三档：相对词 → 本周内逐日（带星期后缀）→「X月其他时间」（本月剩余）→ 逐月（跨年带年份）。
// develop@21c8115 上 `_addFutureSkeletons` 是「从明天起每 28 天铺一组、铺到明年年底」，
// 既没有「X月其他时间」，也没有逐月桶，只有 11月28日 / 12月26日 / 1月23日 这类散点。
//
// 时钟钉 2026-11-02（周一）：本周日 = 11-08，于是
//   逐日档 = 明天(11/3)、后天(11/4)、11月5日 周四、11月6日 周五、11月7日 周六、11月8日 周日
//   本月剩余 = 十一月其他时间
//   逐月 = 十二月、2027年一月 … 2027年十二月
// 反向对照钉「条目那天不重复铺空组」（#526 第一面的不变量），免得改档位时把那条改回退。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 2, 9);

List<String> _sectionKeys(WidgetTester tester) {
  final out = <String>[];
  void walk(Element e) {
    final k = e.widget.key;
    if (k is ValueKey<String> && k.value.startsWith('section_')) {
      out.add(k.value.substring('section_'.length));
    }
    e.visitChildren(walk);
  }

  walk(tester.binding.rootElement!);
  return out;
}

Future<void> _pump(WidgetTester tester, InMemoryReminderRepository repo) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  repo.nowProvider = () => _now;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      reminderRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => _now),
    ],
    child: const MaterialApp(home: TaskScaffold(openListId: 'smart.scheduled')),
  ));
  await tester.pumpAndSettle();
}

Future<InMemoryReminderRepository> _repo() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  return repo;
}

void main() {
  testWidgets('#527 骨架档位：本周逐日 → 本月其他时间 → 逐月（跨年带年份）', (tester) async {
    final repo = await _repo();
    // 计划视图在「整表零条目」时走空态引导（不渲染分区），故种一条让列表体出现；
    // 它的组头正好是相对词「明天」，也在下面的完整档位序里。
    await repo.upsertItem(ReminderItem(
      id: 'i-nov3',
      listId: 'list.work',
      title: '明天项',
      dueAt: DateTime(2026, 11, 3, 8),
    ));
    await _pump(tester, repo);

    expect(
      _sectionKeys(tester),
      <String>[
        '明天',
        '后天',
        '11月5日 周四',
        '11月6日 周五',
        '11月7日 周六',
        '11月8日 周日',
        '十一月其他时间',
        '十二月',
        '2027年一月',
        '2027年二月',
        '2027年三月',
        '2027年四月',
        '2027年五月',
        '2027年六月',
        '2027年七月',
        '2027年八月',
        '2027年九月',
        '2027年十月',
        '2027年十一月',
        '2027年十二月',
      ],
      reason: '#527：三档骨架应精确铺出，且不留 28 天步长的散点',
    );
  });

  testWidgets('#527 本月剩余只有一个「X月其他时间」，无 28 天散点', (tester) async {
    final repo = await _repo();
    // 月中条目：仍走 #479 的带星期后缀标签，不应被拆成两个组。
    await repo.upsertItem(ReminderItem(
      id: 'i-nov20',
      listId: 'list.work',
      title: '月中项',
      dueAt: DateTime(2026, 11, 20, 9),
    ));
    await _pump(tester, repo);

    final keys = _sectionKeys(tester);
    expect(keys.where((k) => k == '十一月其他时间').length, 1,
        reason: '本月剩余只出现一个桶');
    expect(keys, contains('11月20日 周五'), reason: '条目那天用自己的组头');
    expect(keys.contains('11月28日 周六'), isFalse,
        reason: '#527：28 天步长的空组散点应消失');
    expect(keys.contains('12月26日 周六'), isFalse, reason: '同上');
    expect(keys.contains('1月23日 周六'), isFalse, reason: '同上');
  });

  testWidgets('#527 反向对照：本周逐日仍不为已有条目那天再铺空组（#526 不变量）',
      (tester) async {
    final repo = await _repo();
    await repo.upsertItem(ReminderItem(
      id: 'i-nov3',
      listId: 'list.work',
      title: '明天项',
      dueAt: DateTime(2026, 11, 3, 8),
    ));
    await repo.upsertItem(ReminderItem(
      id: 'i-nov5',
      listId: 'list.work',
      title: '周四项',
      dueAt: DateTime(2026, 11, 5, 9),
    ));
    await _pump(tester, repo);

    final keys = _sectionKeys(tester);
    expect(keys.where((k) => k == '明天').length, 1,
        reason: '11-03 的条目在「明天」组，骨架不得再铺裸键「11月3日」');
    expect(keys, isNot(contains('11月3日')));
    expect(keys.where((k) => k == '11月5日 周四').length, 1,
        reason: '同一天不得出现两个头（一个带后缀一个不带）');
  });
}
