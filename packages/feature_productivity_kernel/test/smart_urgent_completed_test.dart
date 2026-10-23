import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// 线框新智能卡（2026-10-22-lifeos-wireframes 客户端画板）契约：
/// - `smart.urgent`：未完成且（当日过期 ∨ priority>=9）
/// - `smart.completed`：已完成全部（D2 预留入口落地）
/// 双实现（InMemory/Drift）行为一致由 drift 侧同名用例保证。
void main() {
  late InMemoryReminderRepository repo;

  setUp(() {
    repo = InMemoryReminderRepository(seedSampleData: false);
    repo.nowForTest = DateTime(2026, 10, 23, 12, 0);
    repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  });

  group('smart.urgent（当日过期 ∨ priority>=9）', () {
    test('当日过期未完成入选；昨日过期不入选；未来不入选', () async {
      await repo.upsertItem(
        ReminderItem(
          id: 'u1',
          listId: 'list.work',
          title: '今天过期',
          dueAt: DateTime(2026, 10, 23, 8), // 今天早上已过时刻
        ),
      );
      await repo.upsertItem(
        ReminderItem(
          id: 'u2',
          listId: 'list.work',
          title: '昨天过期',
          dueAt: DateTime(2026, 10, 22, 8),
        ),
      );
      await repo.upsertItem(
        ReminderItem(
          id: 'u3',
          listId: 'list.work',
          title: '明天到期',
          dueAt: DateTime(2026, 10, 24, 8),
        ),
      );

      final urgent = await repo.watchItems(listId: 'smart.urgent').first;
      expect(urgent.map((e) => e.id), ['u1']);
    });

    test('priority>=9 未完成入选（无论是否有日期）；已完成高优不入选', () async {
      await repo.upsertItem(
        const ReminderItem(
          id: 'h1',
          listId: 'list.work',
          title: '高优无日期',
          priority: 9,
        ),
      );
      await repo.upsertItem(
        const ReminderItem(
          id: 'h2',
          listId: 'list.work',
          title: '已完成高优',
          priority: 9,
          isCompleted: true,
        ),
      );

      final urgent = await repo.watchItems(listId: 'smart.urgent').first;
      expect(urgent.map((e) => e.id), ['h1']);
    });

    test('紧急卡计数回写 watchLists', () async {
      await repo.upsertItem(
        ReminderItem(
          id: 'u1',
          listId: 'list.work',
          title: '今天过期',
          dueAt: DateTime(2026, 10, 23, 8),
        ),
      );
      final lists = await repo.watchLists().first;
      expect(
        lists.firstWhere((e) => e.id == 'smart.urgent').itemCount,
        1,
      );
    });
  });

  group('smart.completed（已完成入口）', () {
    test('只含已完成；与 smart.all 互斥', () async {
      await repo.upsertItem(
        const ReminderItem(
          id: 'c1',
          listId: 'list.work',
          title: '已完成',
          isCompleted: true,
        ),
      );
      await repo.upsertItem(
        const ReminderItem(id: 'c2', listId: 'list.work', title: '未完成'),
      );

      final completed =
          await repo.watchItems(listId: 'smart.completed').first;
      expect(completed.map((e) => e.id), ['c1']);

      final all = await repo.watchItems(listId: 'smart.all').first;
      expect(all.map((e) => e.id), ['c2']);
    });

    test('完成卡计数 = 已完成条数（回写）', () async {
      await repo.upsertItem(
        const ReminderItem(
          id: 'c1',
          listId: 'list.work',
          title: 'A',
          isCompleted: true,
        ),
      );
      await repo.upsertItem(
        const ReminderItem(
          id: 'c2',
          listId: 'list.work',
          title: 'B',
          isCompleted: true,
        ),
      );
      final lists = await repo.watchLists().first;
      expect(
        lists.firstWhere((e) => e.id == 'smart.completed').itemCount,
        2,
      );
    });

    test('toggleCompleted 后完成卡即时可见（流广播）', () async {
      await repo.upsertItem(
        const ReminderItem(id: 'x1', listId: 'list.work', title: 'X'),
      );
      await repo.toggleCompleted('x1');

      final completed =
          await repo.watchItems(listId: 'smart.completed').first;
      expect(completed.map((e) => e.id), ['x1']);
    });
  });

  test('智能列表种子含紧急/完成两卡且次序在旗标之后', () async {
    final lists = await repo.watchLists().first;
    final ids =
        lists.where((e) => e.isSmart).map((e) => e.id).toList();
    expect(ids, containsAll(['smart.urgent', 'smart.completed']));
    expect(ids.indexOf('smart.urgent'), greaterThan(ids.indexOf(
        'smart.flagged')));
  });
}
