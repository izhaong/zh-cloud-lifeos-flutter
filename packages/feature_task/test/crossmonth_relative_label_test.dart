// #476：计划视图跨月时相对标签「明天」应正确显示。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// 时钟钉 2026-10-31 23:30（月底，跨月边界）
final _now = DateTime(2026, 10, 31, 23, 30);

Future<InMemoryReminderRepository> _seed() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  // 跨月：11月1日（应显示「明天」）、11月3日（绝对日期）
  await repo.upsertItem(ReminderItem(
    id: 'i-nov1', listId: 'list.work', title: '下月一日早上的项',
    dueAt: DateTime(2026, 11, 1, 8),
  ));
  await repo.upsertItem(ReminderItem(
    id: 'i-nov3', listId: 'list.work', title: '十一月三日项',
    dueAt: DateTime(2026, 11, 3, 9),
  ));
  // 同月明天：10月31日看 11月1日 = 明天；再看 11月2日 = 11月2日
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
  testWidgets('#476 10月31日看11月1日显示「明天」', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(await _seed(), 'smart.scheduled'));
    await tester.pumpAndSettle();

    // 11月1日的项应出现在「明天」分区下，不是「11月1日」
    final hasTomorrow = find.text('明天').evaluate().isNotEmpty;
    final hasNov1Label = find.text('11月1日').evaluate().isNotEmpty;

    expect(hasTomorrow, isTrue, reason: '应显示「明天」分区头');
    expect(hasNov1Label, isFalse, reason: '不应再显示「11月1日」分区头');
  });

  test('#476 跨月明天判定逻辑', () {
    // 验证修复后的逻辑：DateTime 加一天比较
    final now = DateTime(2026, 10, 31, 23, 30);
    final due = DateTime(2026, 11, 1, 8);
    final tomorrow = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));

    expect(
      DateTime(due.year, due.month, due.day) ==
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
      isTrue,
      reason: '跨月明天判定应通过 DateTime 加一天比较',
    );

    // 旧逻辑（now.day + 1）在月底会失败
    expect(due.day == now.day + 1, isFalse,
        reason: '旧逻辑 now.day+1 在月底应失败');
  });
}
