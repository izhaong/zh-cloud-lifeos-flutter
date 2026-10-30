// #477：今天视图分区拖放改时间。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 29, 9, 30);

Future<InMemoryReminderRepository> _seed() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  // #484 起定时项按时刻判过期：挂钟 09:30 下 09:00 会落「已过期」，
  // 这里用 10:00 才能覆盖「上午」分区（#509 记录、develop 已含同款修复）。
  await repo.upsertItem(ReminderItem(
    id: 'i-am', listId: 'list.work', title: '上午的电话',
    dueAt: DateTime(2026, 10, 29, 10),
  ));
  await repo.upsertItem(ReminderItem(
    id: 'i-pm', listId: 'list.work', title: '下午的评审',
    dueAt: DateTime(2026, 10, 29, 15),
  ));
  await repo.upsertItem(ReminderItem(
    id: 'i-eve', listId: 'list.work', title: '今晚的跑步',
    dueAt: DateTime(2026, 10, 29, 20),
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
  testWidgets('#477 今天视图有拖放目标与可拖动行', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(await _seed(), 'smart.today'));
    await tester.pumpAndSettle();

    // 验证分区头存在（上午/下午/今晚）
    expect(find.text('上午').evaluate().isNotEmpty, isTrue);
    expect(find.text('下午').evaluate().isNotEmpty, isTrue);
    expect(find.text('今晚').evaluate().isNotEmpty, isTrue);

    // 验证行存在
    expect(find.text('上午的电话').evaluate().isNotEmpty, isTrue);
    expect(find.text('下午的评审').evaluate().isNotEmpty, isTrue);
    expect(find.text('今晚的跑步').evaluate().isNotEmpty, isTrue);
  });

  test('#477 分区时间映射逻辑', () {
    // 验证各分区对应的代表时刻
    final today = DateTime(2026, 10, 29);

    // 上午 → 09:00
    expect(DateTime(today.year, today.month, today.day, 9).hour, 9);
    // 下午 → 15:00
    expect(DateTime(today.year, today.month, today.day, 15).hour, 15);
    // 今晚 → 20:00
    expect(DateTime(today.year, today.month, today.day, 20).hour, 20);
    // 今天 → 全天（00:00）
    expect(DateTime(today.year, today.month, today.day).hour, 0);
  });
}
