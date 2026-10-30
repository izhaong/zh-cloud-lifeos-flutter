import 'package:drift/native.dart';

import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-SYNC-107/108/112 客户端半边：本地变更落发件箱（幂等键不换）
/// + push 回执 serverId 回填 `reminder_items.remote_id`（flutter#124 卡 2）。
void main() {
  late LifeProductivityDb db;
  late DriftReminderRepository repo;
  late DriftSyncOutbox outbox;

  setUp(() async {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftReminderRepository(db);
    outbox = DriftSyncOutbox(db);
    // 夹具直插行、不走 repo.upsertList：flutter#144 起清单写入也会登记
    // 出站（entityType=list），会把本文件「只测 task 出站」的断言多算一条。
    await db.into(db.reminderLists).insert(
          ReminderListsCompanion.insert(
              id: 'list.personal', title: '个人'));
  });

  tearDown(() async {
    await db.close();
  });

  Future<ReminderItem?> row(String id) async {
    final items = await repo.watchItems(listId: 'list.personal').first;
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  test('V11：发件箱表随 schemaVersion 11 建表', () async {
    expect(db.schemaVersion, 23,
        reason: 'V11 发件箱、V12 游标、V13 任务偏好（flutter#124 卡 2/3/4）');
    expect(await outbox.pending(), isEmpty);
  });

  test('TC-SYNC-107 离线新建：变更入队并带载荷快照', () async {
    await repo.upsertItem(
        const ReminderItem(id: 'i1', listId: 'list.personal', title: '买牛奶'));

    final entry = (await outbox.pending()).single;
    expect(entry.entityType, 'task');
    expect(entry.entityId, 'i1');
    expect(entry.operation, 'upsert');
    expect(entry.payload['title'], '买牛奶');
    expect(entry.payload['listId'], 'list.personal');
    expect(entry.clientMutationId, isNotEmpty, reason: '幂等键在入队时就生成');
    expect(entry.clientUpdatedAt, greaterThan(0));
  });

  test('TC-SYNC-107 离线改 3 条：队列 3 条、按编辑顺序待推', () async {
    await repo.upsertItem(
        const ReminderItem(id: 'a', listId: 'list.personal', title: 'A'));
    await repo.upsertItem(
        const ReminderItem(id: 'b', listId: 'list.personal', title: 'B'));
    await repo.upsertItem(
        const ReminderItem(id: 'c', listId: 'list.personal', title: 'C'));

    expect((await outbox.pending()).map((e) => e.entityId), ['a', 'b', 'c']);
  });

  test('TC-SYNC-108 同条二次编辑合并：仍一条、幂等键不换、载荷取最新', () async {
    await repo.upsertItem(
        const ReminderItem(id: 'i1', listId: 'list.personal', title: '初稿'));
    final first = (await outbox.pending()).single;
    await repo.upsertItem(const ReminderItem(
        id: 'i1', listId: 'list.personal', title: '终稿', priority: 9));

    final pending = await outbox.pending();
    expect(pending, hasLength(1), reason: '未推的同一实体合并成一条');
    final again = pending.single;
    expect(again.clientMutationId, first.clientMutationId,
        reason: '断网重试/二次编辑都不得换幂等键（服务端按键去重）');
    expect(again.payload['title'], '终稿');
    expect(again.payload['priority'], 3,
        reason: '载荷走服务端 0–3 档（LifeosTaskDO 冻结 + DB CHECK），客户端 9 要换算');
  });

  test('TC-SYNC-107 完成/旗标/移动/删除都入队；删除记 delete', () async {
    await repo.upsertItem(
        const ReminderItem(id: 'i1', listId: 'list.personal', title: '买牛奶'));
    await repo.upsertItem(const ReminderItem(
        id: 'i2', listId: 'list.personal', title: '子项', parentId: 'i1'));
    await db.into(db.reminderLists).insert(
          ReminderListsCompanion.insert(
              id: 'list.work', title: '工作'));

    await repo.toggleCompleted('i1');
    await repo.toggleFlagged('i1');
    await repo.moveItem('i1', 'list.work');
    await repo.deleteItem('i1');

    final byId = {for (final e in await outbox.pending()) e.entityId: e};
    expect(byId['i1']!.operation, 'delete',
        reason: '删除覆盖此前的 upsert（同一幂等键）');
    // 级联：子任务随父进回收窗，也必须各记一条 delete（服务端同口径级联）
    expect(byId['i2']!.operation, 'delete');
    expect(byId['i1']!.payload['deletedAt'], isNotNull);
  });

  test('TC-SYNC-112 回执带 serverId：清队并回填 remote_id', () async {
    await repo.upsertItem(
        const ReminderItem(id: 'i1', listId: 'list.personal', title: '买牛奶'));
    expect((await row('i1'))!.remoteId, isNull);

    await outbox.acknowledge(
        entityType: 'task', entityId: 'i1', serverId: 'srv-77');

    expect(await outbox.pending(), isEmpty);
    expect((await row('i1'))!.remoteId, 'srv-77',
        reason: 'serverId 即本地 remoteId 来源（临时 ID 映射收口）');
  });

  test('TC-SYNC-112 无 serverId 的回执（冲突让位）：只清队、不动 remote_id',
      () async {
    await repo.upsertItem(const ReminderItem(
        id: 'i1', listId: 'list.personal', title: '买牛奶', remoteId: 'srv-old'));

    await outbox.acknowledge(entityType: 'task', entityId: 'i1');

    expect(await outbox.pending(), isEmpty);
    expect((await row('i1'))!.remoteId, 'srv-old');
  });

  test('TC-SYNC-112 回填只认 task 实体：list 回执不写条目表', () async {
    // 同名 id 的条目 + 列表：list 回执若误写条目表就会串到条目上
    await repo.upsertItem(
        const ReminderItem(id: 'list.personal', listId: 'list.personal', title: '同名条目'));
    await outbox.enqueue(const SyncOutboxEntry(
      entityType: 'list',
      entityId: 'list.personal',
      operation: 'upsert',
      payload: {'id': 'list.personal', 'name': '个人'},
      clientMutationId: 'cm-list',
      clientUpdatedAt: 1,
    ));

    await outbox.acknowledge(
        entityType: 'list', entityId: 'list.personal', serverId: 'srv-l1');

    // 同名条目自己那条 task 变更仍在队里（按实体类型分别出队，不串）
    expect((await outbox.pending()).single.entityType, 'task');
    final sameIdItem = await (db.select(db.reminderItems)
          ..where((t) => t.id.equals('list.personal')))
        .getSingle();
    expect(sameIdItem.remoteId, isNull,
        reason: '本卡只回填 task 的 remoteId；列表无 remoteId 列，不得串写');
  });
}
