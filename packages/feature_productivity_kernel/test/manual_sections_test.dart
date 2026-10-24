import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// TC-KR-118 手动分区建模（M2）：
/// - 分区元数据（id/标题/排序）由列表携带（sections 字段）
/// - item.sectionId 挂靠分区；无 sectionId 或挂已删分区 → 兜底「未分区」
/// - 分区随列表删除清理（软删级联）；与 dueAt 日桶互斥（一列表一种分组模式）
/// - reorderSection/upsertSection 语义
void main() {
  late InMemoryReminderRepository repo;

  setUp(() {
    repo = InMemoryReminderRepository(seedSampleData: false);
    repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作'),
    );
  });

  group('TC-KR-118 分区元数据与挂靠', () {
    test('upsertSection 新增/更新分区元数据，watchLists 广播', () async {
      await repo.upsertSection(
        listId: 'list.work',
        section: const ReminderSection(id: 'sec1', title: '进行中'),
      );
      final lists = await repo.watchLists().first;
      final sections =
          lists.firstWhere((e) => e.id == 'list.work').sections;
      expect(sections.map((s) => s.title), ['进行中']);

      // 更新标题
      await repo.upsertSection(
        listId: 'list.work',
        section: const ReminderSection(id: 'sec1', title: '收尾中'),
      );
      final lists2 = await repo.watchLists().first;
      expect(
        lists2.firstWhere((e) => e.id == 'list.work').sections
            .map((s) => s.title),
        ['收尾中'],
      );
    });

    test('reorderSection 保序列稳定', () async {
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
      final sections =
          lists.firstWhere((e) => e.id == 'list.work').sections;
      expect(sections.map((s) => s.id), ['s2', 's1']);
    });

    test('deleteSection 级联：条目兜底「未分区」', () async {
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
      // 条目仍在、sectionId 清空（兜底未分区）
      final items = await repo.watchItems(listId: 'list.work').first;
      expect(items.firstWhere((e) => e.id == 'i1').sectionId, isNull);
    });

    test('deleteList 软删级联不残留分区元数据', () async {
      await repo.upsertSection(
        listId: 'list.work',
        section: const ReminderSection(id: 'sec1', title: '进行中'),
      );
      await repo.deleteList('list.work');
      final lists = await repo.watchLists().first;
      expect(lists.where((e) => e.id == 'list.work'), isEmpty);
    });
  });
}
