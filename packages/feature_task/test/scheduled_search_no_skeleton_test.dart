// #531：计划视图在「搜索态」仍渲染整棵未来空骨架（匹配结果被十几屏空月头淹没）。
// 金标准：Apple 提醒事项搜索时只呈现匹配结果（按日期分组），不铺空的未来日期组。
//
// 时钟钉 2026-11-02（周一），与非搜索态的三档骨架用例同源：
//   非搜索态应铺「十二月 / 2027年一月 …」（本文件第一段，反向对照）；
//   输入搜索词后只剩命中项那天（第二段，判据）。
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

void main() {
  testWidgets('#531 搜索态只留命中项的日期组，未来空骨架不渲染', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryReminderRepository(seedSampleData: false);
    repo.nowProvider = () => _now;
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
    await repo.upsertItem(ReminderItem(
      id: 'i-hit',
      listId: 'list.work',
      title: 'REG2 采购',
      dueAt: DateTime(2026, 11, 20, 9),
    ));
    await repo.upsertItem(ReminderItem(
      id: 'i-miss',
      listId: 'list.work',
      title: '另一项',
      dueAt: DateTime(2026, 12, 25, 9),
    ));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: const MaterialApp(home: TaskScaffold(openListId: 'smart.scheduled')),
    ));
    await tester.pumpAndSettle();

    // 反向对照：同一产物在不搜索时确实铺了逐月骨架，
    // 否则下面的「搜索态无骨架」会因为骨架压根没渲染而恒真。
    final idleKeys = _sectionKeys(tester);
    expect(idleKeys, contains('十一月其他时间'), reason: '非搜索态三档骨架要在');
    expect(idleKeys, contains('2027年一月'), reason: '非搜索态逐月骨架要在');

    await tester.enterText(find.byKey(const ValueKey('toolbar_search')), 'REG2');
    await tester.pumpAndSettle();

    final keys = _sectionKeys(tester);
    expect(
      keys,
      <String>['11月20日 周五'],
      reason: '搜索态只应有命中项那一组，未来空骨架（含 2027 全年月头）不得出现',
    );
    expect(
      keys.any((k) => k.startsWith('2027年')),
      isFalse,
      reason: '搜索态不应再铺未来月骨架',
    );
  });
}
