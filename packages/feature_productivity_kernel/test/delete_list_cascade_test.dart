import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// ADR / TC-KR-108（parity#175）：删除含提醒的列表的级联语义。
///
/// 拍板口径（与 TC-SYNC-109 回收窗、TC-KR-105 父删子树同一套窗口语义）：
/// 1. 列表下提醒**随列表进 30 天最近删除窗**（软删，不硬删），可从「最近删除」逐条恢复；
/// 2. 列表本身从侧栏移除，其提醒计数立刻归零（同一次广播内完成）；
/// 3. 原列表已删时，恢复落「首个自有列表」（Apple 默认列表口径）。
void main() {
  late InMemoryReminderRepository repo;

  setUp(() async {
    repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '工作'));
    await repo.upsertList(const ReminderList(id: 'list.b', title: '个人'));
    await repo.upsertItem(
      const ReminderItem(id: 'r1', listId: 'list.a', title: '甲'),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'r2', listId: 'list.a', title: '乙'),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'r3', listId: 'list.b', title: '丙'),
    );
  });

  test('删除列表：其提醒进最近删除，计数归零，其它列表不受影响', () async {
    await repo.deleteList('list.a');

    final lists = await repo.watchLists().first;
    expect(lists.any((l) => l.id == 'list.a'), isFalse, reason: '列表从侧栏移除');
    expect(
      lists.firstWhere((l) => l.id == 'smart.trash').itemCount,
      2,
      reason: '两条提醒进回收窗',
    );
    expect(
      lists.firstWhere((l) => l.id == 'smart.all').itemCount,
      1,
      reason: '只剩 list.b 的丙',
    );

    final trash = await repo.watchItems(listId: 'smart.trash').first;
    expect(trash.map((e) => e.id), containsAll(<String>['r1', 'r2']));
    expect(trash.map((e) => e.id), isNot(contains('r3')));
  });

  test('从最近删除恢复：原列表已删 → 落首个自有列表', () async {
    await repo.deleteList('list.a');
    await repo.restoreItem('r1');

    final personal = await repo.watchItems(listId: 'list.b').first;
    expect(personal.map((e) => e.id), contains('r1'));
    final trash = await repo.watchItems(listId: 'smart.trash').first;
    expect(trash.map((e) => e.id), isNot(contains('r1')));
  });

  test('已完成提醒同样进回收窗且计数含已完成（PR2 口径）', () async {
    await repo.toggleCompleted('r2');
    await repo.deleteList('list.a');

    final lists = await repo.watchLists().first;
    expect(
      lists.firstWhere((l) => l.id == 'smart.trash').itemCount,
      2,
      reason: '回收站计数含已完成项',
    );
  });
}
