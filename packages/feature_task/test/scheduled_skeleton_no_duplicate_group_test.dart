// #526：#487 的未来骨架自己拼「M月d日」，与条目组键（相对词 / 带星期后缀）永不相等，
// 于是同一天出现两个组头：
//   section_明天 + section_11月1日（11-01 的条目在「明天」里，骨架又铺一个空组）
//   section_11月3日 周二 + section_11月3日（同一天两个头，只差后缀）
// #476 的负向断言「不应再显示『11月1日』分区头」正是被这条打红的（不是用例过期）。
//
// 判红设计：修复前 11月1日 / 11月3日 两种裸键都存在 ⇒ 前两条断言红；
// 反向对照钉骨架本身还在（11月28日 那档空组仍渲染），
// 免得把骨架整段删掉也算修好——骨架步长该是「逐月」而不是 28 天，
// 那是 #526 的第二面，本用例不管。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 31, 23, 30);

/// 收集渲染树里所有分区键（`section_<组名>`），含未滚动到的。
List<String> _sectionKeys(WidgetTester tester) {
  final out = <String>[];
  void walk(Element e) {
    final k = e.widget.key;
    if (k is ValueKey<String> && k.value.startsWith('section_')) {
      out.add(k.value);
    }
    e.visitChildren(walk);
  }
  walk(tester.binding.rootElement!);
  return out;
}

void main() {
  testWidgets('骨架不得为已有条目那天再铺一个空组头', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
    await repo.upsertItem(ReminderItem(
      id: 'i-nov1',
      listId: 'list.work',
      title: '下月一日项',
      dueAt: DateTime(2026, 11, 1, 8),
    ));
    await repo.upsertItem(ReminderItem(
      id: 'i-nov3',
      listId: 'list.work',
      title: '下月三日项',
      dueAt: DateTime(2026, 11, 3, 9),
    ));
    repo.nowProvider = () => _now;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: const MaterialApp(home: TaskScaffold(openListId: 'smart.scheduled')),
    ));
    await tester.pumpAndSettle();

    final keys = _sectionKeys(tester);
    expect(keys, contains('section_明天'), reason: '11-01 的条目仍在「明天」组（#476）');
    expect(keys, isNot(contains('section_11月1日')),
        reason: '#526：骨架不得再为 11-01 铺一个空的「11月1日」组');
    expect(keys, contains('section_11月3日 周二'), reason: '11-03 走 #479 的带星期后缀');
    expect(keys, isNot(contains('section_11月3日')),
        reason: '#526：同一天不得出现「11月3日」与「11月3日 周二」两个头');

    // 反向对照：骨架本身还在（28 天步长那档），本卡没把 #487 的功能删掉。
    expect(keys.any((k) => k.startsWith('section_11月28日')), isTrue,
        reason: '#526 只修重复组头，骨架步长留作本单第二面');
  });
}
