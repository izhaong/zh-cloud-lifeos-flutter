import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #2 · M2 第三批：「最近删除」本地回收窗（TC-UI-109 / TC-API-110 本地侧）
/// 删除=软删（deletedAt）；smart.trash 视图=30 天窗口；restoreItem 恢复（子树随行、
/// 原列表已删落首个自有列表）；purgeExpiredDeleted 清超期。
void main() {
  late InMemoryReminderRepository repo;

  setUp(() async {
    repo = InMemoryReminderRepository(seedSampleData: false)
      ..nowForTest = DateTime(2026, 10, 24, 10, 0);
    await repo.upsertList(
        const ReminderList(id: 'list.a', title: 'A'));
    await repo.upsertItem(
        const ReminderItem(id: 'i1', listId: 'list.a', title: '买牛奶'));
    await repo.upsertItem(const ReminderItem(
        id: 'sub1', listId: 'list.a', title: '子任务', parentId: 'i1'));
  });

  test('删除进回收窗：列表/智能视图缺席，smart.trash 可见', () async {
    await repo.deleteItem('i1');

    expect((await repo.watchItems(listId: 'list.a').first), isEmpty);
    expect((await repo.watchItems(listId: 'smart.all').first), isEmpty);
    final trash = await repo.watchItems(listId: 'smart.trash').first;
    expect(trash.map((e) => e.id), containsAll(['i1', 'sub1'])); // 子树随行
    expect(trash.firstWhere((e) => e.id == 'i1').deletedAt,
        DateTime(2026, 10, 24, 10, 0));

    // 智能列表元数据含「最近删除」
    final lists = await repo.watchLists().first;
    expect(lists.map((e) => e.id), contains('smart.trash'));
  });

  test('restoreItem 恢复子树回原列表', () async {
    await repo.deleteItem('i1');
    await repo.restoreItem('i1');

    final back = await repo.watchItems(listId: 'list.a').first;
    expect(back.map((e) => e.id), containsAll(['i1', 'sub1']));
    expect(back.firstWhere((e) => e.id == 'i1').deletedAt, isNull);
    expect((await repo.watchItems(listId: 'smart.trash').first), isEmpty);
  });

  test('原列表已删：恢复落首个自有列表（Apple 默认列表口径）', () async {
    await repo.upsertList(
        const ReminderList(id: 'list.b', title: 'B'));
    await repo.deleteList('list.a'); // 条目随列表入回收窗
    await repo.restoreItem('i1');

    final inB = await repo.watchItems(listId: 'list.b').first;
    expect(inB.map((e) => e.id), contains('i1'));
  });

  test('purgeExpiredDeleted 只清 30 天窗外', () async {
    await repo.deleteItem('i1');
    // 冻结时间推进 31 天再清
    repo.nowForTest = DateTime(2026, 11, 24, 10, 0);
    final removed = await repo.purgeExpiredDeleted();

    expect(removed, 2); // i1 + sub1
    expect((await repo.watchItems(listId: 'smart.trash').first), isEmpty);
  });
}
