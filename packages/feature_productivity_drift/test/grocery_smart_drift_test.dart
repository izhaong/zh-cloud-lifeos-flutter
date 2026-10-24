import 'package:drift/native.dart';

import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// cursor PR#15 审查缺口补测：drift 生产路径下 grocery / custom smart
/// 真正持久化（upsertList 写 sectionsJson + isSmart）。
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

  test('grocery 工厂落库：8 分区入 sectionsJson，reorderSection 可操作',
      () async {
    final grocery = ReminderList.createGroceryList(
      id: 'list.g1',
      title: '周采购',
    );
    await repo.upsertList(grocery);

    final lists = await repo.watchLists().first;
    final stored = lists.firstWhere((e) => e.id == 'list.g1');
    expect(stored.listType, ReminderListType.grocery);
    expect(stored.sections.length, 8, reason: '分区随列表持久化');
    expect(stored.sections.first.title, '农产品');

    // reorderSection 有对象可操作（镜像非空）
    final ids = stored.sections.map((e) => e.id).toList().reversed.toList();
    await repo.reorderSection(listId: 'list.g1', sectionIds: ids);
    final after = await repo.watchLists().first;
    expect(
      after.firstWhere((e) => e.id == 'list.g1').sections.first.title,
      '日用品', // 重排生效 = 镜像真接上了
    );
  });

  test('deleteSection 对 grocery 落库分区级联清 sectionId', () async {
    final grocery = ReminderList.createGroceryList(
      id: 'list.g2',
      title: '采购',
    );
    await repo.upsertList(grocery);
    final sec0 = grocery.sections.first;
    await repo.upsertItem(
      ReminderItem(
        id: 'm1',
        listId: 'list.g2',
        title: '牛奶',
        sectionId: sec0.id,
      ),
    );

    await repo.deleteSection(listId: 'list.g2', sectionId: sec0.id);
    final lists = await repo.watchLists().first;
    expect(
      lists.firstWhere((e) => e.id == 'list.g2').sections.length,
      7,
    );
    final items = await repo.watchItems(listId: 'list.g2').first;
    expect(items.firstWhere((e) => e.id == 'm1').sectionId, isNull);
  });

  test('custom 智能列表落库 isSmart=true（侧栏分区正确）', () async {
    await repo.upsertList(
      const ReminderList(
        id: 'smart.custom.drf',
        title: '旗标精选',
        isSmart: true,
        smartFilter: SmartListFilter(flaggedOnly: true),
      ),
    );
    final lists = await repo.watchLists().first;
    final stored = lists.firstWhere((e) => e.id == 'smart.custom.drf');
    expect(stored.isSmart, isTrue, reason: 'drift 生产路径 isSmart 持久化');
    expect(stored.smartFilter?.flaggedOnly, isTrue);
  });

  test('守卫正反向：smart.custom.x 放行；smart.today 仍拒（drift 侧）', () {
    expect(
      () => repo.upsertList(
        const ReminderList(id: 'smart.today', title: '篡改'),
      ),
      throwsArgumentError,
    );
    // 放行不抛
    repo.upsertList(
      const ReminderList(id: 'smart.custom.ok', title: '合法', isSmart: true),
    );
  });
}
