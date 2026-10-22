import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

void main() {
  group('WindowSizeClass.fromWidth 断点边界', () {
    test('599 / 600 归档位', () {
      expect(WindowSizeClass.fromWidth(0), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(375), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(599.9), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
    });

    test('1199 / 1200 归档位', () {
      expect(WindowSizeClass.fromWidth(1199.9), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(1200), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1366), WindowSizeClass.expanded);
    });

    test('分栏能力位', () {
      expect(WindowSizeClass.compact.isPaneLayout, isFalse);
      expect(WindowSizeClass.medium.isPaneLayout, isTrue);
      expect(WindowSizeClass.expanded.isPaneLayout, isTrue);
      expect(WindowSizeClass.medium.supportsDetailPane, isFalse);
      expect(WindowSizeClass.expanded.supportsDetailPane, isTrue);
    });
  });

  group('InMemoryReminderRepository 契约', () {
    late InMemoryReminderRepository repo;

    setUp(() {
      repo = InMemoryReminderRepository(seedSampleData: false);
      repo.nowForTest = DateTime(2026, 10, 22, 12, 0);
      repo.upsertList(const ReminderList(id: 'list.personal', title: '个人'));
      repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
    });

    test('watchLists 首帧后，upsertList 广播新值', () async {
      final first = await repo.watchLists().first;
      expect(first.map((e) => e.id),
        containsAll(const ['list.personal', 'list.work']));

      final emitted = <List<ReminderList>>[];
      final sub = repo.watchLists().listen(emitted.add);
      await pumpEventQueue();
      await repo.upsertList(
        const ReminderList(id: 'list.shopping', title: '购物'),
      );
      await pumpEventQueue();
      expect(emitted.last.map((e) => e.id), contains('list.shopping'));
      await sub.cancel();
    });

    test('toggleCompleted 后未完成计数回写列表', () async {
      await repo.upsertItem(
        const ReminderItem(id: 'i1', listId: 'list.personal', title: '买牛奶'),
      );
      final before = await repo.watchLists().first;
      expect(
        before.firstWhere((e) => e.id == 'list.personal').itemCount,
        1,
      );

      await repo.toggleCompleted('i1');
      final after = await repo.watchLists().first;
      expect(
        after.firstWhere((e) => e.id == 'list.personal').itemCount,
        0,
      );
    });

    test('smart.today 只含今天未完成', () async {
      await repo.upsertItem(
        ReminderItem(
          id: 't1',
          listId: 'list.personal',
          title: '今天到期',
          dueAt: DateTime(2026, 10, 22, 9, 0),
        ),
      );
      await repo.upsertItem(
        ReminderItem(
          id: 't2',
          listId: 'list.personal',
          title: '明天到期',
          dueAt: DateTime(2026, 10, 23, 9, 0),
        ),
      );
      await repo.upsertItem(
        ReminderItem(
          id: 't3',
          listId: 'list.personal',
          title: '今天但已完成',
          dueAt: DateTime(2026, 10, 22, 9, 0),
          isCompleted: true,
        ),
      );

      final today = await repo.watchItems(listId: 'smart.today').first;
      expect(today.map((e) => e.id), ['t1']);
    });

    test('smart.scheduled = 有日期且未完成；smart.flagged = 旗标且未完成', () async {
      await repo.upsertItem(
        ReminderItem(
          id: 's1',
          listId: 'list.work',
          title: '有日期',
          dueAt: DateTime(2026, 10, 22, 9, 0),
        ),
      );
      await repo.upsertItem(
        const ReminderItem(id: 's2', listId: 'list.work', title: '无日期'),
      );
      await repo.upsertItem(
        const ReminderItem(
          id: 's3',
          listId: 'list.work',
          title: '旗标',
          isFlagged: true,
        ),
      );

      final scheduled = await repo.watchItems(listId: 'smart.scheduled').first;
      expect(scheduled.map((e) => e.id), ['s1']);

      final flagged = await repo.watchItems(listId: 'smart.flagged').first;
      expect(flagged.map((e) => e.id), ['s3']);
    });

    test('smart.all 不含已完成；upsertItem 全字段回写', () async {
      await repo.upsertItem(
        const ReminderItem(id: 'a1', listId: 'list.work', title: '初稿'),
      );
      await repo.upsertItem(
        const ReminderItem(
          id: 'a1',
          listId: 'list.work',
          title: '定稿',
          notes: '备注',
          isFlagged: true,
          priority: 9,
        ),
      );

      final all = await repo.watchItems(listId: 'smart.all').first;
      final item = all.singleWhere((e) => e.id == 'a1');
      expect(item.title, '定稿');
      expect(item.notes, '备注');
      expect(item.isFlagged, isTrue);
      expect(item.priority, 9);
    });

    test('watchItems 写操作后广播新快照（无手动 reload）', () async {
      final emitted = <List<ReminderItem>>[];
      final sub = repo.watchItems(listId: 'list.personal').listen(emitted.add);
      await pumpEventQueue();

      await repo.upsertItem(
        const ReminderItem(id: 'n1', listId: 'list.personal', title: '新提醒'),
      );
      await pumpEventQueue();
      expect(emitted.last.map((e) => e.id), contains('n1'));
      await sub.cancel();
    });
  });
}
