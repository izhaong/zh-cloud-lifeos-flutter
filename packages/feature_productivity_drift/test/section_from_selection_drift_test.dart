// flutter #567：Drift 侧的「用所选项目新建分区」原子写。
//
// 与 kernel 那份判据互为镜像（InMemory ≡ Drift 是本仓既有纪律）。校验必须排在写
// 之前——否则中途失败会在 `reminder_sections` 里留下半个分区，而 Apple 没有这个中间态。
// 这里刻意用**裸表**读回：只有直接查表才看得出事务到底回滚了没有。
import 'package:drift/native.dart';

import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LifeProductivityDb db;
  late DriftReminderRepository repo;

  setUp(() async {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftReminderRepository(db);
    await repo.upsertList(const ReminderList(id: 'list.p', title: '个人'));
    await repo.upsertList(const ReminderList(id: 'list.q', title: '另一个清单'));
    for (final (id, listId, title) in [
      ('i1', 'list.p', '甲'),
      ('i2', 'list.p', '乙'),
      ('i3', 'list.p', '丙'),
      ('x1', 'list.q', '别列表的那条'),
    ]) {
      await repo.upsertItem(ReminderItem(id: id, listId: listId, title: title));
    }
  });

  tearDown(() async => db.close());

  Future<List<String>> sectionRowIds() async =>
      [for (final r in await db.select(db.reminderSections).get()) r.id];

  Future<String?> sectionIdOf(String itemId) async {
    final row = await (db.select(
      db.reminderItems,
    )..where((t) => t.id.equals(itemId))).getSingle();
    return row.sectionId;
  }

  group('TC-KR-122 Drift 镜像：一次事务 1 分区 + N 归属', () {
    test('所选两条进分区，第三条留在未分区，别的清单不受扰', () async {
      await repo.createSectionWithTasks(
        listId: 'list.p',
        section: const ReminderSection(id: 'sec.new', title: '采购', sortOrder: 1),
        itemIds: const ['i1', 'i2'],
      );

      expect(await sectionRowIds(), ['sec.new']);
      expect(await sectionIdOf('i1'), 'sec.new');
      expect(await sectionIdOf('i2'), 'sec.new');
      expect(await sectionIdOf('i3'), isNull, reason: '没选中的不能被卷进来');
      expect(await sectionIdOf('x1'), isNull, reason: '别的清单不受扰');
    });

    test('判据 1 的原子性：跨列表 id ⇒ 抛错，分区行与归属都没落', () async {
      await expectLater(
        repo.createSectionWithTasks(
          listId: 'list.p',
          section: const ReminderSection(
            id: 'sec.bad',
            title: '半个分区',
            sortOrder: 1,
          ),
          itemIds: const ['i1', 'x1'],
        ),
        throwsStateError,
      );

      expect(await sectionRowIds(), isEmpty, reason: '分区本体必须一起回滚');
      expect(
        await sectionIdOf('i1'),
        isNull,
        reason: 'i1 的归属不能已经落下去（先写后验就露在这里）',
      );
    });

    test('空选择集不写分区（UI 未选中时的兜底，不给 Apple 没有的中间态）', () async {
      await expectLater(
        repo.createSectionWithTasks(
          listId: 'list.p',
          section: const ReminderSection(
            id: 'sec.empty',
            title: '空选择',
            sortOrder: 1,
          ),
          itemIds: const [],
        ),
        throwsArgumentError,
      );
      expect(
        await sectionRowIds(),
        isEmpty,
        reason: '一条都没选 ⇒ 不产出分区',
      );
    });
  });
}
