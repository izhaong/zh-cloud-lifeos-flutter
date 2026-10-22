import 'package:drift/native.dart';

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

  test('toggleCompleted 后计数变化 + 全字段回写', () async {
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
}
