import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-KR-118 手动分区 Drift 对照（与 InMemory 行为一致）+ TC-KR-109 V3→V4 迁移。
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

  group('TC-KR-118 分区元数据（Drift ↔ InMemory 对照）', () {
    test('upsertSection 新增/更新 + watchLists 排序回读', () async {
      await repo.upsertList(
        const ReminderList(id: 'list.work', title: '工作'),
      );
      await repo.upsertSection(
        listId: 'list.work',
        section: const ReminderSection(id: 'sec1', title: '进行中'),
      );
      var lists = await repo.watchLists().first;
      expect(
        lists.firstWhere((e) => e.id == 'list.work').sections
            .map((s) => s.title),
        ['进行中'],
      );

      await repo.upsertSection(
        listId: 'list.work',
        section: const ReminderSection(id: 'sec1', title: '收尾中'),
      );
      lists = await repo.watchLists().first;
      expect(
        lists.firstWhere((e) => e.id == 'list.work').sections
            .map((s) => s.title),
        ['收尾中'],
      );
    });

    test('reorderSection 保序（sortOrder asc 契约）', () async {
      await repo.upsertList(
        const ReminderList(id: 'list.work', title: '工作'),
      );
      await repo.upsertSection(
        listId: 'list.work',
        section: const ReminderSection(id: 's1', title: 'A', sortOrder: 0),
      );
      await repo.upsertSection(
        listId: 'list.work',
        section: const ReminderSection(id: 's2', title: 'B', sortOrder: 1),
      );
      await repo.reorderSection(
        listId: 'list.work',
        sectionIds: const ['s2', 's1'],
      );
      final lists = await repo.watchLists().first;
      expect(
        lists.firstWhere((e) => e.id == 'list.work').sections
            .map((s) => s.id),
        ['s2', 's1'],
      );
    });

    test('deleteSection 级联：条目兜底未分区', () async {
      await repo.upsertList(
        const ReminderList(id: 'list.work', title: '工作'),
      );
      await repo.upsertSection(
        listId: 'list.work',
        section: const ReminderSection(id: 'sec1', title: '进行中'),
      );
      await repo.upsertItem(
        const ReminderItem(
          id: 'i1',
          listId: 'list.work',
          title: '任务A',
          sectionId: 'sec1',
        ),
      );

      await repo.deleteSection(listId: 'list.work', sectionId: 'sec1');

      final lists = await repo.watchLists().first;
      expect(
        lists.firstWhere((e) => e.id == 'list.work').sections,
        isEmpty,
      );
      final items = await repo.watchItems(listId: 'list.work').first;
      expect(items.firstWhere((e) => e.id == 'i1').sectionId, isNull);
    });
  });

  group('TC-KR-109 V3→V4 迁移', () {
    test('V3 旧库升级：sectionsJson 有默认 []，旧数据保留', () async {
      // 裸 sqlite3 建 V3 旧结构（无 sectionsJson）
      final raw = sqlite3.sqlite3.openInMemory();
      raw.execute('''
        CREATE TABLE reminder_lists (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          color_argb INTEGER NOT NULL DEFAULT 4280327039,
          is_smart INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0
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
          sort_order INTEGER NOT NULL DEFAULT 0
        );
      ''');
      raw.execute('PRAGMA user_version = 3');
      raw.execute(
        "INSERT INTO reminder_lists (id, title) VALUES ('legacy', '旧列表')",
      );

      final db2 = LifeProductivityDb(NativeDatabase.opened(raw));
      final lists = await db2.select(db2.reminderLists).get();
      expect(lists.map((e) => e.id), contains('legacy'));
      final legacy = lists.firstWhere((e) => e.id == 'legacy');
      // V3 旧行经 addColumn 后为 NULL（非 DEFAULT）——读取层兜底为空分区
      expect(legacy.sectionsJson, isNull);
      // 走仓库读取：NULL 兜底空分区元数据，不炸
      final repo2 = DriftReminderRepository(db2);
      final viaRepo = await repo2.watchLists().first;
      expect(
        viaRepo.firstWhere((e) => e.id == 'legacy').sections,
        isEmpty,
      );
      await db2.close();
    });
  });
}
