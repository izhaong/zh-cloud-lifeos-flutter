import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #2 · cursor 评审债收口：toggleCompleted 联动 completedAt（TC-UI-107 契约字段侧）。
/// 完成 → completedAt=now；取消完成 → 清空；重复条目滚动 → 保持未完成（completedAt=null）。
void main() {
  late InMemoryReminderRepository repo;

  setUp(() {
    repo = InMemoryReminderRepository(seedSampleData: false)
      ..nowForTest = DateTime(2026, 10, 24, 10, 0);
    repo.upsertList(const ReminderList(id: 'l1', title: '列表'));
  });

  test('完成 → completedAt 记录当下；取消完成 → 清空', () async {
    await repo.upsertItem(
      const ReminderItem(id: 'i1', listId: 'l1', title: '买牛奶'),
    );

    await repo.toggleCompleted('i1');
    var item = (await repo.watchItems(listId: 'l1').first).single;
    expect(item.isCompleted, isTrue);
    expect(item.completedAt, DateTime(2026, 10, 24, 10, 0));

    await repo.toggleCompleted('i1');
    item = (await repo.watchItems(listId: 'l1').first).single;
    expect(item.isCompleted, isFalse);
    expect(item.completedAt, isNull);
  });

  test('重复条目完成滚动：完成态回 false 且 completedAt 保持 null', () async {
    await repo.upsertItem(
      const ReminderItem(
        id: 'r1',
        listId: 'l1',
        title: '每天喂狗',
        recurrence: 'daily',
      ).copyWith(dueAt: DateTime(2026, 10, 24, 8, 0)),
    );

    await repo.toggleCompleted('r1');
    final item = (await repo.watchItems(listId: 'l1').first).single;
    expect(item.isCompleted, isFalse);
    expect(item.completedAt, isNull);
    expect(item.dueAt, DateTime(2026, 10, 25, 8, 0)); // 滚动到下次
  });
}
