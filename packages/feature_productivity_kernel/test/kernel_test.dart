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

    test('copyWith 哨兵可显式置空 notes/dueAt/recurrence/parentId/tags', () {
      final item = ReminderItem(
        id: 'x1',
        listId: 'list.personal',
        title: 'T',
        notes: '备注',
        dueAt: DateTime(2026, 10, 22, 9),
        recurrence: 'daily',
        parentId: 'p1',
        tags: const ['工作'],
      );

      final cleared = item.copyWith(
        notes: ReminderItem.clear,
        dueAt: ReminderItem.clear,
        recurrence: ReminderItem.clear,
        parentId: ReminderItem.clear,
        tags: ReminderItem.clear,
      );
      expect(cleared.notes, isNull);
      expect(cleared.dueAt, isNull);
      expect(cleared.recurrence, isNull);
      expect(cleared.parentId, isNull);
      expect(cleared.tags, isEmpty);
      // 未传字段保持不变
      expect(cleared.title, 'T');
      expect(cleared.id, 'x1');
      expect(cleared, isNot(equals(item)));
    });

    test('toggleCompleted 对带重复规则条目滚动下一次 dueAt（overdue 跳到未来）', () async {
      await repo.upsertItem(
        ReminderItem(
          id: 'r1',
          listId: 'list.personal',
          title: '每日打卡',
          dueAt: DateTime(2026, 10, 20, 8), // 已过期两天
          recurrence: 'daily',
        ),
      );
      await repo.toggleCompleted('r1');

      final items = await repo.watchItems(listId: 'list.personal').first;
      final item = items.singleWhere((e) => e.id == 'r1');
      expect(item.isCompleted, isFalse); // 滚动后回到未完成
      expect(item.dueAt, DateTime(2026, 10, 23, 8)); // 明天 8 点
    });

    test('toggleFlagged 切换旗标', () async {
      await repo.upsertItem(
        const ReminderItem(id: 'f1', listId: 'list.work', title: '旗标'),
      );
      await repo.toggleFlagged('f1');
      var items = await repo.watchItems(listId: 'smart.flagged').first;
      expect(items.map((e) => e.id), ['f1']);

      await repo.toggleFlagged('f1');
      items = await repo.watchItems(listId: 'smart.flagged').first;
      expect(items, isEmpty);
    });

    test('deleteItem 级联删除子任务（多层）', () async {
      await repo.upsertItem(
        const ReminderItem(id: 'p', listId: 'list.work', title: '父'),
      );
      await repo.upsertItem(
        const ReminderItem(
          id: 'c1',
          listId: 'list.work',
          title: '子1',
          parentId: 'p',
        ),
      );
      await repo.upsertItem(
        const ReminderItem(
          id: 'c2',
          listId: 'list.work',
          title: '孙',
          parentId: 'c1',
        ),
      );
      await repo.upsertItem(
        const ReminderItem(id: 'other', listId: 'list.work', title: '无关'),
      );

      await repo.deleteItem('p');
      final items = await repo.watchItems(listId: 'list.work').first;
      expect(items.map((e) => e.id), ['other']);
    });

    test('deleteList 级联删除列表条目', () async {
      await repo.upsertItem(
        const ReminderItem(id: 'a', listId: 'list.work', title: 'A'),
      );
      await repo.deleteList('list.work');
      final items = await repo.watchItems(listId: 'list.work').first;
      expect(items, isEmpty);
      final lists = await repo.watchLists().first;
      expect(lists.map((e) => e.id), isNot(contains('list.work')));
    });

    test('排序契约：sortOrder asc, id asc', () async {
      await repo.upsertItem(
        const ReminderItem(id: 'b', listId: 'list.work', title: 'B',
            sortOrder: 2),
      );
      await repo.upsertItem(
        const ReminderItem(id: 'a', listId: 'list.work', title: 'A',
            sortOrder: 1),
      );
      await repo.upsertItem(
        const ReminderItem(id: 'c', listId: 'list.work', title: 'C',
            sortOrder: 1),
      );

      final items = await repo.watchItems(listId: 'list.work').first;
      expect(items.map((e) => e.id), ['a', 'c', 'b']);
    });

    test('upsertList 拒绝 smart. 前缀 id', () async {
      expect(
        () => repo.upsertList(
          const ReminderList(id: 'smart.hack', title: '黑客'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Recurrence.nextOccurrence 纯函数', () {
    test('daily 跨月', () {
      final next = Recurrence.daily.nextOccurrence(
        DateTime(2026, 10, 31, 8),
        DateTime(2026, 10, 31, 9),
      );
      expect(next, DateTime(2026, 11, 1, 8));
    });

    test('weekly 保持同 weekday', () {
      final wed = DateTime(2026, 10, 21, 8); // 周三
      final next = Recurrence.weekly.nextOccurrence(
        wed,
        DateTime(2026, 10, 21, 9),
      );
      expect(next, DateTime(2026, 10, 28, 8));
      expect(next.weekday, DateTime.wednesday);
    });

    test('monthly 31 日钳制到月末', () {
      final next = Recurrence.monthly.nextOccurrence(
        DateTime(2026, 1, 31, 8),
        DateTime(2026, 1, 31, 9),
      );
      expect(next, DateTime(2026, 2, 28, 8));
    });

    test('yearly 闰年 2 月 29', () {
      final next = Recurrence.yearly.nextOccurrence(
        DateTime(2024, 2, 29, 8),
        DateTime(2024, 2, 29, 9),
      );
      expect(next, DateTime(2025, 2, 28, 8));
    });

    test('weekdays 跳过周末', () {
      // 2026-10-23 周五 → 下一个工作日应为周一 10-26
      final next = Recurrence.weekdays.nextOccurrence(
        DateTime(2026, 10, 23, 8),
        DateTime(2026, 10, 23, 9),
      );
      expect(next, DateTime(2026, 10, 26, 8));
      expect(next.weekday, DateTime.monday);
    });

    test('overdue 推进到 > now', () {
      final next = Recurrence.daily.nextOccurrence(
        DateTime(2026, 10, 20, 8),
        DateTime(2026, 10, 22, 12),
      );
      expect(next, DateTime(2026, 10, 23, 8));
    });
  });
}
