import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drift 仓库契约测试：与 InMemory 对同一端口行为一致（内存库，无真实文件）。
void main() {
  late LifeProductivityDb db;
  late DriftReminderRepository repo;

  setUp(() {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftReminderRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('watchLists 初始为智能列表四项', () async {
    final lists = await repo.watchLists().first;
    expect(
      lists.map((e) => e.id),
      containsAll(
        ['smart.today', 'smart.scheduled', 'smart.all', 'smart.flagged'],
      ),
    );
  });

  test('upsertList/upsertItem 后 watchItems 与计数回写', () async {
    await repo.upsertList(
      const ReminderList(id: 'list.personal', title: '个人'),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'i1', listId: 'list.personal', title: '买牛奶'),
    );

    final items = await repo.watchItems(listId: 'list.personal').first;
    expect(items.map((e) => e.id), ['i1']);

    final lists = await repo.watchLists().first;
    expect(
      lists.firstWhere((e) => e.id == 'list.personal').itemCount,
      1,
    );
  });

  test('toggleCompleted 后计数变化 + 全字段回写（含 tags JSON）', () async {
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'w1', listId: 'list.work', title: '初稿'),
    );
    await repo.upsertItem(
      const ReminderItem(
        id: 'w1',
        listId: 'list.work',
        title: '定稿',
        notes: '备注',
        isFlagged: true,
        priority: 9,
        tags: ['工作', '设计'],
      ),
    );

    final listsBefore = await repo.watchLists().first;
    expect(
      listsBefore.firstWhere((e) => e.id == 'list.work').itemCount,
      1,
    );

    await repo.toggleCompleted('w1');
    final listsAfter = await repo.watchLists().first;
    expect(
      listsAfter.firstWhere((e) => e.id == 'list.work').itemCount,
      0,
    );

    final allItems = await repo.watchItems(listId: 'list.work').first;
    final item = allItems.singleWhere((e) => e.id == 'w1');
    expect(item.title, '定稿');
    expect(item.notes, '备注');
    expect(item.isFlagged, isTrue);
    expect(item.priority, 9);
    expect(item.isCompleted, isTrue);
    expect(item.tags, ['工作', '设计']);
  });

  test('smart.flagged 语义过滤与写后广播', () async {
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
    final emitted = <List<ReminderItem>>[];
    final sub = repo.watchItems(listId: 'smart.flagged').listen(emitted.add);
    await pumpEventQueue();

    await repo.upsertItem(
      const ReminderItem(
        id: 'f1',
        listId: 'list.work',
        title: '旗标项',
        isFlagged: true,
      ),
    );
    await pumpEventQueue();
    expect(emitted.last.map((e) => e.id), contains('f1'));
    await sub.cancel();
  });

  test('数据跨实例持久（真实落库语义）', () async {
    await repo.upsertList(
      const ReminderList(id: 'list.keep', title: '留存'),
    );
    final repo2 = DriftReminderRepository(db);
    final lists = await repo2.watchLists().first;
    expect(lists.map((e) => e.id), contains('list.keep'));
  });

  test('toggleCompleted 对带重复规则条目滚动下一次 dueAt（与 InMemory 一致）',
      () async {
    repo.nowForTest = DateTime(2026, 10, 22, 12);
    await repo.upsertList(
      const ReminderList(id: 'list.personal', title: '个人'),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'r1',
        listId: 'list.personal',
        title: '每日打卡',
        dueAt: DateTime(2026, 10, 20, 8), // 已过期
        recurrence: 'daily',
      ),
    );
    await repo.toggleCompleted('r1');

    final items = await repo.watchItems(listId: 'list.personal').first;
    final item = items.singleWhere((e) => e.id == 'r1');
    expect(item.isCompleted, isFalse);
    expect(item.dueAt, DateTime(2026, 10, 23, 8));
  });

  test('deleteItem 级联删除子任务（多层）', () async {
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
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
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'a', listId: 'list.work', title: 'A'),
    );
    await repo.deleteList('list.work');
    final items = await repo.watchItems(listId: 'list.work').first;
    expect(items, isEmpty);
  });

  test('排序契约：sortOrder asc, id asc（与 InMemory 一致）', () async {
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
    // 故意乱序写入
    await repo.upsertItem(
      const ReminderItem(
          id: 'b', listId: 'list.work', title: 'B', sortOrder: 2),
    );
    await repo.upsertItem(
      const ReminderItem(
          id: 'a', listId: 'list.work', title: 'A', sortOrder: 1),
    );
    await repo.upsertItem(
      const ReminderItem(
          id: 'c', listId: 'list.work', title: 'C', sortOrder: 1),
    );

    final items = await repo.watchItems(listId: 'list.work').first;
    expect(items.map((e) => e.id), ['a', 'c', 'b']);
  });

  test('toggleFlagged 切换旗标', () async {
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'f1', listId: 'list.work', title: '旗标'),
    );
    await repo.toggleFlagged('f1');
    var flagged = await repo.watchItems(listId: 'smart.flagged').first;
    expect(flagged.map((e) => e.id), ['f1']);

    await repo.toggleFlagged('f1');
    flagged = await repo.watchItems(listId: 'smart.flagged').first;
    expect(flagged, isEmpty);
  });

  test('upsertList 拒绝 smart. 前缀 id', () async {
    expect(
      () => repo.upsertList(
        const ReminderList(id: 'smart.hack', title: '黑客'),
      ),
      throwsArgumentError,
    );
  });

  test('V1→V2 迁移：旧数据保留、新列默认值正确', () async {
    // 步骤1：裸 sqlite3 建 V1 旧结构（真实表名，无 V2 新列）+ 旧数据
    final raw = sqlite3.sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE reminder_items (
        id TEXT NOT NULL PRIMARY KEY,
        list_id TEXT NOT NULL,
        title TEXT NOT NULL,
        notes TEXT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_flagged INTEGER NOT NULL DEFAULT 0,
        due_at INTEGER NULL,
        priority INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute('''
      CREATE TABLE reminder_lists (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        color_argb INTEGER NOT NULL DEFAULT 4280327039,
        is_smart INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute(
      'INSERT INTO reminder_items (id, list_id, title, is_completed, '
      'is_flagged, priority) '
      "VALUES ('legacy1', 'list.old', '旧条目', 0, 1, 5)",
    );
    raw.execute('PRAGMA user_version = 1');

    // 步骤2：drift 打开 → beforeOpen 检测 1→2 → onUpgrade 补列
    final db2 = LifeProductivityDb(NativeDatabase.opened(raw));
    final rows = await db2.select(db2.reminderItems).get();
    expect(rows.map((e) => e.id), contains('legacy1'));
    final legacy = rows.singleWhere((e) => e.id == 'legacy1');
    expect(legacy.tags, '[]'); // V2 新列默认值
    expect(legacy.recurrence, isNull);
    expect(legacy.parentId, isNull);
    expect(legacy.sortOrder, 0);
    expect(legacy.title, '旧条目'); // 旧数据未丢
    await db2.close();
  });

  test('V2→V3 迁移（Issue #3）：旧数据保留、契约四列默认 NULL', () async {
    // V2 结构 = V1 + tags/recurrence/parent_id/sort_order + lists.sort_order
    final raw = sqlite3.sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE reminder_items (
        id TEXT NOT NULL PRIMARY KEY,
        list_id TEXT NOT NULL,
        title TEXT NOT NULL,
        notes TEXT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_flagged INTEGER NOT NULL DEFAULT 0,
        due_at INTEGER NULL,
        priority INTEGER NOT NULL DEFAULT 0,
        tags TEXT NOT NULL DEFAULT '[]',
        recurrence TEXT NULL,
        parent_id TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute('''
      CREATE TABLE reminder_lists (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        color_argb INTEGER NOT NULL DEFAULT 4280327039,
        is_smart INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute(
      'INSERT INTO reminder_items (id, list_id, title, tags) '
      "VALUES ('v2row', 'list.x', 'V2 条目', '[\"工作\"]')",
    );
    raw.execute('PRAGMA user_version = 2');

    final db3 = LifeProductivityDb(NativeDatabase.opened(raw));
    final rows = await db3.select(db3.reminderItems).get();
    final v2row = rows.singleWhere((e) => e.id == 'v2row');
    expect(v2row.title, 'V2 条目'); // 旧数据未丢
    expect(v2row.tags, '["工作"]');
    expect(v2row.remoteId, isNull); // V3 契约四列默认
    expect(v2row.completedAt, isNull);
    expect(v2row.sectionId, isNull);
    expect(v2row.deletedAt, isNull);
    await db3.close();
  });

  test('契约字段（remoteId/completedAt/sectionId/deletedAt）经仓库往返',
      () async {
    await repo.upsertList(
      const ReminderList(id: 'list.personal', title: '个人'),
    );
    // 仓内约定：本地墙钟 DateTime（drift 存绝对时刻、往返稳定）；
    // UTC 换算归 M4 同步边界（映射表文档裁定，TC-KR-101）。
    final completed = DateTime(2026, 10, 24, 1, 0);
    await repo.upsertItem(
      const ReminderItem(id: 'c1', listId: 'list.personal', title: '契约条目')
          .copyWith(
        remoteId: 'srv-77',
        completedAt: completed,
        sectionId: 'sec-1',
      ),
    );

    final item =
        (await repo.watchItems(listId: 'list.personal').first).single;
    expect(item.remoteId, 'srv-77');
    expect(item.completedAt, completed);
    expect(item.sectionId, 'sec-1');
    expect(item.deletedAt, isNull);

    // 更新：清分区（移动列表语义 TC-API-118）+ 落回收窗（TC-API-110）
    final now = DateTime(2026, 10, 24, 2, 30);
    await repo.upsertItem(
      item.copyWith(
        sectionId: ReminderItem.clear,
        deletedAt: now,
      ),
    );
    final updated =
        (await repo.watchItems(listId: 'list.personal').first).single;
    expect(updated.sectionId, isNull);
    expect(updated.deletedAt, now);
  });
}
