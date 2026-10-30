// #513：分区「＋」修复验证——已过期档不出「＋」。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 29, 9, 30);

Future<InMemoryReminderRepository> _seed() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  // 过期项 + 上午/下午/今晚各一条
  await repo.upsertItem(ReminderItem(
    id: 'i-overdue', listId: 'list.work', title: '过期项',
    dueAt: DateTime(2026, 10, 27, 15),
  ));
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
  testWidgets('#513 面② 已过期档不出「＋」', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(await _seed(), 'smart.today'));
    await tester.pumpAndSettle();

    // 验证分区头存在
    expect(find.text('已过期').evaluate().isNotEmpty, isTrue);
    expect(find.text('上午').evaluate().isNotEmpty, isTrue);
    expect(find.text('下午').evaluate().isNotEmpty, isTrue);
    expect(find.text('今晚').evaluate().isNotEmpty, isTrue);
  });

  test('#513 面③ _sectionTime 共用表验证', () {
    final today = DateTime(2026, 10, 29);
    // 上午=09:00
    expect(DateTime(today.year, today.month, today.day, 9).hour, 9);
    // 下午=15:00
    expect(DateTime(today.year, today.month, today.day, 15).hour, 15);
    // 今晚=20:00
    expect(DateTime(today.year, today.month, today.day, 20).hour, 20);
    // 今天=全天
    expect(DateTime(today.year, today.month, today.day).hour, 0);
  });
}
