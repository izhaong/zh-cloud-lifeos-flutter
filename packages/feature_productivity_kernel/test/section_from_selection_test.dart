// flutter #567（TC-KR-122）：「用所选项目新建分区」的端口语义。
//
// 对等矩阵行 37 要的是**一次原子写**：产出 1 个分区 + 把所选 N 条挂进去。
// 本文件钉住 InMemory 这一侧的两半——正判据（选中的进、没选中的不动）
// 与负判据（任一 id 不属于该列表 ⇒ 一字不写，不许留下半个分区）。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryReminderRepository repo;

  setUp(() async {
    repo = InMemoryReminderRepository(seedSampleData: false);
    repo.disposeDayRolloverWatch(); // 定时器会留下「A Timer is still pending」
    await repo.upsertList(const ReminderList(id: 'list.p', title: '个人'));
    await repo.upsertList(const ReminderList(id: 'list.q', title: '另一个清单'));
    for (final (id, title) in [('i1', '甲'), ('i2', '乙'), ('i3', '丙')]) {
      await repo.upsertItem(
        ReminderItem(id: id, listId: 'list.p', title: title),
      );
    }
    await repo.upsertItem(
      const ReminderItem(id: 'x1', listId: 'list.q', title: '别列表的那条'),
    );
  });

  Future<List<ReminderItem>> itemsOf(String listId) =>
      repo.watchItems(listId: listId).first;

  Future<List<ReminderSection>> sectionsOf(String listId) async =>
      (await repo.watchLists().first).firstWhere((e) => e.id == listId).sections;

  group('TC-KR-122 用所选项目新建分区（对等矩阵行 37 / flutter #567）', () {
    test('一次调用产出 1 个分区 + 所选 2 条归属；没选中的那条不动', () async {
      await repo.createSectionWithTasks(
        listId: 'list.p',
        section: const ReminderSection(id: 'sec.new', title: '采购', sortOrder: 1),
        itemIds: const ['i1', 'i2'],
      );

      expect(await sectionsOf('list.p'), hasLength(1), reason: '只产出这一个分区');
      final items = await itemsOf('list.p');
      expect(
        {for (final e in items) if (e.sectionId != null) e.id},
        {'i1', 'i2'},
        reason: 'i3 没被选中，不能被卷进分区',
      );
      expect(items.firstWhere((e) => e.id == 'i1').sectionId, 'sec.new');
      expect(items.firstWhere((e) => e.id == 'i2').sectionId, 'sec.new');
    });

    test('判据 1 的负向：任一 id 不属于该列表 ⇒ 抛 StateError 且一字不写', () async {
      await expectLater(
        repo.createSectionWithTasks(
          listId: 'list.p',
          section: const ReminderSection(id: 'sec.bad', title: '半个分区', sortOrder: 1),
          // x1 属 list.q：Apple 没有「先建空分区再逐条挂」的中间态
          itemIds: const ['i1', 'x1'],
        ),
        throwsStateError,
      );

      expect(
        await sectionsOf('list.p'),
        isEmpty,
        reason: '回滚要连分区本体一起退回去（否则留下半个分区）',
      );
      expect(
        await sectionsOf('list.q'),
        isEmpty,
        reason: '另一个清单也不该被顺手写入',
      );
      for (final e in await itemsOf('list.p')) {
        expect(e.sectionId, isNull, reason: '${e.id} 的归属不能已经落下去');
      }
    });

    test('空选择集 ⇒ ArgumentError（端口不认「建一个空分区」这个别名）', () async {
      await expectLater(
        repo.createSectionWithTasks(
          listId: 'list.p',
          section: const ReminderSection(id: 'sec.empty', title: '空', sortOrder: 1),
          itemIds: const [],
        ),
        throwsArgumentError,
      );
      expect(await sectionsOf('list.p'), isEmpty);
    });

    test('重复 id 不产生重复归属（选择集按集合处理）', () async {
      await repo.createSectionWithTasks(
        listId: 'list.p',
        section: const ReminderSection(id: 'sec.dup', title: '重复', sortOrder: 1),
        itemIds: const ['i1', 'i1', 'i2'],
      );
      final items = await itemsOf('list.p');
      expect(items.where((e) => e.sectionId == 'sec.dup').map((e) => e.id).toSet(),
          {'i1', 'i2'});
      expect(await sectionsOf('list.p'), hasLength(1));
    });
  });
}
