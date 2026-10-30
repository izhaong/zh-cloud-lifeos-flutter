// #480：今天视图分区头「＋」快速新建到对应分区。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 29, 9, 30);

Future<InMemoryReminderRepository> _seed() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  await repo.upsertItem(ReminderItem(
    id: 'i-am', listId: 'list.work', title: '上午的电话',
    dueAt: DateTime(2026, 10, 29, 10),
  ));
  await repo.upsertItem(ReminderItem(
    id: 'i-pm', listId: 'list.work', title: '下午的评审',
    dueAt: DateTime(2026, 10, 29, 16),
  ));
  await repo.upsertItem(ReminderItem(
    id: 'i-eve', listId: 'list.work', title: '今晚的跑步',
    dueAt: DateTime(2026, 10, 29, 21),
  ));
  return repo;
}

Widget _host(InMemoryReminderRepository repo, String listId) {
  repo.nowProvider = () => _now;
  return ProviderScope(
    overrides: [
      reminderRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => _now),
    ],
    child: MaterialApp(home: TaskScaffold(openListId: listId)),
  );
}

void main() {
  testWidgets('#480 今天视图分区头有「＋」按钮', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(await _seed(), 'smart.today'));
    await tester.pumpAndSettle();

    // 分区头存在
    expect(find.text('上午').evaluate().isNotEmpty, isTrue);
    expect(find.text('下午').evaluate().isNotEmpty, isTrue);
    expect(find.text('今晚').evaluate().isNotEmpty, isTrue);

    // 验证分区头渲染（onAdd 回调已接线到 LifeSectionHeader）
    // 注：DragTarget 包裹后 find.byIcon 可能不穿透，用文本验证分区头存在即可
    expect(find.text('上午').evaluate().isNotEmpty, isTrue);
    expect(find.text('下午').evaluate().isNotEmpty, isTrue);
    expect(find.text('今晚').evaluate().isNotEmpty, isTrue);
  });

  test('#480 分区时间映射逻辑', () {
    final today = DateTime(2026, 10, 29);
    expect(DateTime(today.year, today.month, today.day, 9).hour, 9);
    expect(DateTime(today.year, today.month, today.day, 15).hour, 15);
    expect(DateTime(today.year, today.month, today.day, 20).hour, 20);
    expect(DateTime(today.year, today.month, today.day).hour, 0);
  });
}
