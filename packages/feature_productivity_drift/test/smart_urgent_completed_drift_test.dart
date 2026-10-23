import 'package:drift/native.dart';

import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// 线框新智能卡（紧急/完成）Drift 侧契约——与 InMemory 同名用例行为一致。
void main() {
  late LifeProductivityDb db;
  late DriftReminderRepository repo;

  setUp(() {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftReminderRepository(db);
    repo.nowForTest = DateTime(2026, 10, 23, 12, 0);
  });

  tearDown(() async {
    await db.close();
  });

  group('smart.urgent（当日过期 ∨ priority>=9）', () {
    test('当日过期未完成入选；昨日过期不入选；未来不入选', () async {
      await repo.upsertList(
        const ReminderList(id: 'list.work', title: '工作'),
      );
      await repo.upsertItem(
        ReminderItem(
          id: 'u1',
          listId: 'list.work',
          title: '今天过期',
          dueAt: DateTime(2026, 10, 23, 8),
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

    test('priority>=9 未完成入选；已完成高优不入选', () async {
      await repo.upsertList(
        const ReminderList(id: 'list.work', title: '工作'),
      );
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
      await repo.upsertList(
        const ReminderList(id: 'list.work', title: '工作'),
      );
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
      await repo.upsertList(
        const ReminderList(id: 'list.work', title: '工作'),
      );
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

    test('完成卡计数 = 已完成条数', () async {
      await repo.upsertList(
        const ReminderList(id: 'list.work', title: '工作'),
      );
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
      await repo.upsertList(
        const ReminderList(id: 'list.work', title: '工作'),
      );
      await repo.upsertItem(
        const ReminderItem(id: 'x1', listId: 'list.work', title: 'X'),
      );
      await repo.toggleCompleted('x1');

      final completed =
          await repo.watchItems(listId: 'smart.completed').first;
      expect(completed.map((e) => e.id), ['x1']);
    });
  });

  test('智能列表派生含紧急/完成两卡', () async {
    final lists = await repo.watchLists().first;
    final ids = lists.map((e) => e.id);
    expect(ids, containsAll(['smart.urgent', 'smart.completed']));
  });
}
