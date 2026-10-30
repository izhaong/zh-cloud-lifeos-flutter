// #482：详情窗新增「提前提醒」字段。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 29, 9, 30);

Future<InMemoryReminderRepository> _seed() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  await repo.upsertItem(ReminderItem(
    id: 'i-task', listId: 'list.work', title: '普通任务',
    dueAt: DateTime(2026, 10, 29, 10),
    earlyReminderAt: DateTime(2026, 10, 29, 9, 30),
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
  testWidgets('#482 详情窗有「提前提醒」字段', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(await _seed(), 'list.work'));
    await tester.pumpAndSettle();

    // 点任务进入详情
    await tester.tap(find.text('普通任务').first);
    await tester.pumpAndSettle();

    // 验证「提前提醒」字段存在
    expect(find.text('提前提醒').evaluate().isNotEmpty, isTrue,
        reason: '详情窗应有「提前提醒」字段');
  });

  test('#482 earlyReminderAt 字段在模型中', () {
    final item = ReminderItem(
      id: 'x', listId: 'l', title: 't',
      earlyReminderAt: DateTime(2026, 10, 29, 9, 30),
    );
    expect(item.earlyReminderAt, isNotNull);
    expect(item.earlyReminderAt!.hour, 9);

    // copyWith 能更新
    final updated = item.copyWith(earlyReminderAt: null);
    expect(updated.earlyReminderAt, isNull);
  });
}
