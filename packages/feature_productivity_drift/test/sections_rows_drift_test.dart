import 'dart:convert';

import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// #169 / TC-SYNC-106、TC-KR-118：分区从 `reminder_lists.sections_json`
/// 整块列拆成 `reminder_sections` 一行一个分区。
///
/// 旧实现的写路径是「读整块 JSON → 改一条 → 写整块」，两台设备离线各改
/// **同一清单的不同分区**时，后到的整块写会把对方那条盖掉。这里钉住：
/// - 单条分区编辑只写自己那行（并发两条都活）
/// - 入站 `task_section` 按行合并（不整块覆盖）
/// - V14→V15 迁移把既有 JSON 搬成行，读取侧改走行
void main() {
  late LifeProductivityDb db;
  late DriftReminderRepository repo;

  setUp(() {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftReminderRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> seedList() => repo.upsertList(
    const ReminderList(
      id: 'list.work',
      title: '工作',
      remoteId: '501',
      sections: [
        ReminderSection(id: 's-fruit', title: '水果', sortOrder: 0),
        ReminderSection(id: 's-veg', title: '蔬菜', sortOrder: 1),
      ],
    ),
  );

  Future<List<ReminderSection>> sectionsOf(String listId) async {
    for (final l in await repo.watchLists().first) {
      if (l.id == listId) return l.sections;
    }
    return const [];
  }

  test('#169 并发改同一清单的不同分区：两条改动都在', () async {
    await seedList();

    // 两台设备各自改一个分区（旧实现两次读同一份 JSON，后写覆盖先写）。
    await Future.wait([
      repo.upsertSection(
        listId: 'list.work',
        section: const ReminderSection(
          id: 's-fruit',
          title: '水果（改）',
          sortOrder: 0,
        ),
      ),
      repo.upsertSection(
        listId: 'list.work',
        section: const ReminderSection(
          id: 's-veg',
          title: '蔬菜',
          sortOrder: 9,
        ),
      ),
    ]);

    final sections = await sectionsOf('list.work');
    final fruit = sections.firstWhere((s) => s.id == 's-fruit');
    final veg = sections.firstWhere((s) => s.id == 's-veg');
    expect(fruit.title, '水果（改）', reason: 'A 的改名不能被 B 的整块写盖掉');
    expect(veg.sortOrder, 9, reason: 'B 的排序不能被 A 的整块写盖掉');
  });

  test('#169 分区各自落成一行（不再是整块 JSON 列）', () async {
    await seedList();
    final rows = await db.select(db.reminderSections).get();
    expect(rows, hasLength(2));
    expect(
      rows.map((r) => r.id).toSet(),
      {'s-fruit', 's-veg'},
      reason: '一条分区一行',
    );
    expect(
      rows.every((r) => r.listId == 'list.work'),
      isTrue,
      reason: '行上带所属清单',
    );
    // 旧列保留作回滚快照，但读取侧不再依赖它。
    final listRow = await db.select(db.reminderLists).getSingle();
    expect(listRow.sectionsJson, '[]', reason: 'V15 起不再维护整块列');
  });

  test('#169 入站 task_section 按行合并：互不覆盖', () async {
    await seedList();

    // A 端把「水果」改名，B 端把「蔬菜」排序改掉，两个载荷先后到达本机。
    await repo.applyAll([
      const SyncIncomingChange(
        entityType: 'task_section',
        entityId: 'remote-fruit',
        operation: 'upsert',
        payload: {
          'id': 'remote-fruit',
          'listId': '501',
          'name': '水果（对端）',
          'sortOrder': 0,
        },
      ),
      const SyncIncomingChange(
        entityType: 'task_section',
        entityId: 'remote-veg',
        operation: 'upsert',
        payload: {
          'id': 'remote-veg',
          'listId': '501',
          'name': '蔬菜（对端）',
          'sortOrder': 7,
        },
      ),
    ]);

    final sections = await sectionsOf('list.work');
    expect(
      sections.map((s) => s.title),
      containsAll(['水果（对端）', '蔬菜（对端）']),
      reason: '两条入站分区都要在（整块覆盖会只剩最后一条）',
    );
    expect(
      sections.firstWhere((s) => s.remoteId == 'remote-veg').sortOrder,
      7,
    );
  });

  test('#169 入站 task_section delete 只删那一行并清条目挂靠', () async {
    await seedList();
    await repo.upsertItem(
      const ReminderItem(
        id: 'i1',
        listId: 'list.work',
        title: '苹果',
        sectionId: 's-fruit',
      ),
    );

    await repo.applyAll([
      const SyncIncomingChange(
        entityType: 'task_section',
        entityId: 's-fruit',
        operation: 'delete',
        payload: {'listId': 'list.work'},
      ),
    ]);

    final sections = await sectionsOf('list.work');
    expect(sections.map((s) => s.id), ['s-veg'], reason: '只删被删的那条');
    final item = await db.select(db.reminderItems).getSingle();
    expect(item.sectionId, isNull, reason: '挂靠条目兜底「未分区」');
  });

  group('V14→V15 迁移', () {
    test('既有 sections_json 搬成行，读取侧走行', () async {
      final raw = sqlite3.openInMemory();
      raw.execute('''
        CREATE TABLE reminder_lists (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          color_argb INTEGER NOT NULL DEFAULT 4280327039,
          is_smart INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          sections_json TEXT NULL DEFAULT '[]',
          group_name TEXT NULL,
          list_type TEXT NULL,
          smart_filter TEXT NULL,
          remote_id TEXT NULL
        );
      ''');
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
          sort_order INTEGER NOT NULL DEFAULT 0,
          remote_id TEXT NULL,
          completed_at INTEGER NULL,
          section_id TEXT NULL,
          deleted_at INTEGER NULL,
          recurrence_until INTEGER NULL
        );
      ''');
      raw.execute(
          'INSERT INTO reminder_lists (id, title, sections_json) VALUES '
          "('l1', '旧清单', ?)",
          [
            jsonEncode([
              {'id': 'a', 'title': '水果', 'sortOrder': 0, 'remoteId': 'r-a'},
              {'id': 'b', 'title': '蔬菜', 'sortOrder': 1},
            ]),
          ]);
      raw.execute('PRAGMA user_version = 14');

      final migrated = LifeProductivityDb(NativeDatabase.opened(raw));
      addTearDown(migrated.close);

      final rows = await migrated.select(migrated.reminderSections).get();
      expect(
        rows.map((r) => r.id).toSet(),
        {'a', 'b'},
        reason: '迁移要把旧 JSON 的每条分区搬成一行',
      );
      expect(
        rows.firstWhere((r) => r.id == 'a').remoteId,
        'r-a',
        reason: 'remoteId 一并搬（后续入站靠它合并）',
      );

      final repo2 = DriftReminderRepository(migrated);
      final lists = await repo2.watchLists().first;
      final sections = lists.singleWhere((l) => l.id == 'l1').sections;
      expect(sections.map((s) => s.title), ['水果', '蔬菜']);
    });

    test('坏 JSON 不阻断整库升级', () async {
      final raw = sqlite3.openInMemory();
      raw.execute('''
        CREATE TABLE reminder_lists (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          color_argb INTEGER NOT NULL DEFAULT 4280327039,
          is_smart INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          sections_json TEXT NULL DEFAULT '[]',
          group_name TEXT NULL,
          list_type TEXT NULL,
          smart_filter TEXT NULL,
          remote_id TEXT NULL
        );
      ''');
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
          sort_order INTEGER NOT NULL DEFAULT 0,
          remote_id TEXT NULL,
          completed_at INTEGER NULL,
          section_id TEXT NULL,
          deleted_at INTEGER NULL,
          recurrence_until INTEGER NULL
        );
      ''');
      raw.execute(
        'INSERT INTO reminder_lists (id, title, sections_json) VALUES '
        "('l1', '坏数据', 'not-json')",
      );
      raw.execute('PRAGMA user_version = 14');

      final migrated = LifeProductivityDb(NativeDatabase.opened(raw));
      addTearDown(migrated.close);

      expect(
        await migrated.select(migrated.reminderSections).get(),
        isEmpty,
        reason: '解析不了的清单跳过，不拖垮升级',
      );
      final lists = await migrated.select(migrated.reminderLists).get();
      expect(lists.single.id, 'l1', reason: '清单本体保留');
    });
  });
}
