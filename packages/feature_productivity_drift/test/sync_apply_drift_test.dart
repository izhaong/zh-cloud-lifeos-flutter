import 'package:drift/native.dart';

import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-SYNC-106/109/112 客户端半边：入站变更落 Drift（delete 走 30 天回收窗、
/// 同 remoteId 不重复物化）与游标持久化（flutter#124 卡 3）。
void main() {
  late LifeProductivityDb db;
  late DriftReminderRepository repo;
  late SyncApplier applier;
  late DriftSyncCursorStore cursors;

  setUp(() async {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftReminderRepository(db);
    // 入站落库由仓库承担（它才是唯一持有行映射的地方）
    applier = repo;
    cursors = DriftSyncCursorStore(db);
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  });

  tearDown(() async {
    await db.close();
  });

  /// 服务端 `LifeosTaskSyncCodec.taskPayload` 的字节形状：日期 epoch 毫秒、
  /// priority 是服务端档（0/1/2/3）、isFlagged 双键。
  Map<String, dynamic> serverPayload(String id, {Map<String, dynamic>? over}) => {
        'id': id,
        'listId': 'list.work',
        'sectionId': 'sec-1',
        'parentTaskId': null,
        'title': '写周报',
        'description': '本周三个里程碑',
        'notes': '本周三个里程碑',
        'dueAt': DateTime(2026, 10, 28, 9, 30).toUtc().millisecondsSinceEpoch,
        'allDay': false,
        'priority': 2,
        'isFlagged': true,
        'is_flagged': true,
        'isCompleted': false,
        'completedAt': null,
        'sortOrder': 7,
        'isPinned': false,
        'deletedAt': null,
        'deletedFromListId': null,
        'revision': 4,
        'tags': const <String>[],
        ...?over,
      };

  Future<List<String>> idsWhereRemote(String remote) async {
    final rows = await (db.select(db.reminderItems)
          ..where((t) => t.remoteId.equals(remote)))
        .get();
    return rows.map((r) => r.id).toList();
  }

  test('TC-SYNC-106 首次全量：入站 upsert 落 Drift 且字段反解正确', () async {
    await applier.applyAll([
      SyncIncomingChange(
        entityType: 'task',
        entityId: 'srv-1',
        operation: 'upsert',
        payload: serverPayload('srv-1'),
      ),
    ]);

    final row = await (db.select(db.reminderItems)
          ..where((t) => t.id.equals('srv-1')))
        .getSingle();
    expect(row.title, '写周报');
    expect(row.notes, '本周三个里程碑');
    expect(row.listId, 'list.work');
    expect(row.sectionId, 'sec-1');
    expect(row.dueAt, DateTime(2026, 10, 28, 9, 30));
    expect(row.priority, 5, reason: '服务端档 2 → 客户端 5（ReminderPriorityCodec）');
    expect(row.isFlagged, isTrue);
    expect(row.sortOrder, 7);
    expect(row.remoteId, 'srv-1', reason: '入站新行的 remoteId 即服务端 id');
  });

  test('TC-SYNC-106 标签与完成态随载荷落库', () async {
    await applier.applyAll([
      SyncIncomingChange(
        entityType: 'task',
        entityId: 'srv-2',
        operation: 'upsert',
        payload: serverPayload('srv-2', over: {
          'tags': ['工作', '设计'],
          'isCompleted': true,
          'completedAt': DateTime(2026, 10, 27, 8).toUtc().millisecondsSinceEpoch,
        }),
      ),
    ]);

    final row = await (db.select(db.reminderItems)
          ..where((t) => t.id.equals('srv-2')))
        .getSingle();
    final items = await repo.watchItems(listId: 'list.work').first;
    expect(items.firstWhere((e) => e.id == 'srv-2').tags, ['工作', '设计']);
    expect(row.isCompleted, isTrue);
    expect(row.completedAt, DateTime(2026, 10, 27, 8));
  });

  test('TC-SYNC-112 同 remoteId 不重复物化：更新原行而不是新建一条', () async {
    // 卡 2 回填过的离线行：本地 id 是 UUID，remoteId 已是 srv-3
    await repo.upsertItem(const ReminderItem(
        id: 'uuid-3', listId: 'list.work', title: '离线建的', remoteId: 'srv-3'));

    await applier.applyAll([
      SyncIncomingChange(
        entityType: 'task',
        entityId: 'srv-3',
        operation: 'upsert',
        payload: serverPayload('srv-3', over: {'title': '对端改的标题'}),
      ),
    ]);

    expect(await idsWhereRemote('srv-3'), ['uuid-3'],
        reason: '重复物化就是把一条任务变成两条（service #327 的同款坑）');
    final row = await (db.select(db.reminderItems)
          ..where((t) => t.id.equals('uuid-3')))
        .getSingle();
    expect(row.title, '对端改的标题');
    expect(
      await (db.select(db.reminderItems)
            ..where((t) => t.id.equals('srv-3')))
          .get(),
      isEmpty,
      reason: '不得再按服务端 id 建第二行',
    );
  });

  test('TC-SYNC-109 入站 delete：进本地 30 天回收窗，不是硬删', () async {
    await applier.applyAll([
      SyncIncomingChange(
        entityType: 'task',
        entityId: 'srv-9',
        operation: 'upsert',
        payload: serverPayload('srv-9'),
      ),
    ]);

    await applier.applyAll([
      const SyncIncomingChange(
        entityType: 'task',
        entityId: 'srv-9',
        operation: 'delete',
        payload: {},
      ),
    ]);

    final row = await (db.select(db.reminderItems)
          ..where((t) => t.id.equals('srv-9')))
        .getSingle();
    expect(row.deletedAt, isNotNull, reason: '与服务端 applier 同口径：软删入窗');
    final listed = await repo.watchItems(listId: 'list.work').first;
    expect(listed.map((e) => e.id), isNot(contains('srv-9')),
        reason: '回收窗行不进普通列表');
    final trash = await repo.watchItems(listId: 'smart.trash').first;
    expect(trash.map((e) => e.id), contains('srv-9'));
  });

  test('TC-SYNC-109 delete 载荷带 deletedAt 时按服务端时间入窗', () async {
    final at = DateTime(2026, 10, 20, 3, 4).toUtc().millisecondsSinceEpoch;
    await applier.applyAll([
      SyncIncomingChange(
        entityType: 'task',
        entityId: 'srv-8',
        operation: 'upsert',
        payload: serverPayload('srv-8'),
      ),
    ]);
    await applier.applyAll([
      SyncIncomingChange(
        entityType: 'task',
        entityId: 'srv-8',
        operation: 'delete',
        payload: {'deletedAt': at},
      ),
    ]);

    final row = await (db.select(db.reminderItems)
          ..where((t) => t.id.equals('srv-8')))
        .getSingle();
    expect(row.deletedAt, DateTime(2026, 10, 20, 3, 4),
        reason: '恢复窗按服务端删除时刻起算，双端才会在同一天过期');
  });

  test('TC-SYNC-109 delete 本地没有的实体：不抛、不影响同批其它变更', () async {
    await applier.applyAll([
      const SyncIncomingChange(
          entityType: 'task',
          entityId: 'ghost',
          operation: 'delete',
          payload: {}),
      SyncIncomingChange(
        entityType: 'task',
        entityId: 'srv-5',
        operation: 'upsert',
        payload: serverPayload('srv-5'),
      ),
    ]);

    expect(
      await (db.select(db.reminderItems)..where((t) => t.id.equals('ghost'))).get(),
      isEmpty,
    );
    expect(
      await (db.select(db.reminderItems)..where((t) => t.id.equals('srv-5'))).get(),
      hasLength(1),
    );
  });

  test('非 task 实体本卡不落条目表（列表/分区实体缺 remoteId 列）', () async {
    await applier.applyAll([
      const SyncIncomingChange(
        entityType: 'list',
        entityId: 'srv-l1',
        operation: 'upsert',
        payload: {'id': 'srv-l1', 'name': '对端列表'},
      ),
    ]);
    expect(
      await (db.select(db.reminderItems)..where((t) => t.id.equals('srv-l1'))).get(),
      isEmpty,
    );
  });

  test('TC-SYNC-106 入站落库不回写发件箱（否则 pull→push 自己造往返）', () async {
    final outbox = DriftSyncOutbox(db);
    await applier.applyAll([
      SyncIncomingChange(
        entityType: 'task',
        entityId: 'srv-20',
        operation: 'upsert',
        payload: serverPayload('srv-20'),
      ),
    ]);

    expect(await outbox.pending(), isEmpty,
        reason: '服务端下推的值不是本地变更；写进发件箱就是把它再推回服务端');
    expect(
      await (db.select(db.reminderItems)..where((t) => t.id.equals('srv-20'))).get(),
      hasLength(1),
      reason: '不落发件箱不等于不落库',
    );
  });

  test('游标持久化：读初值 null、写后回读、再写覆盖为单行', () async {
    expect(await cursors.read(), isNull);
    await cursors.write('c-9');
    expect(await cursors.read(), 'c-9');
    await cursors.write('c-10');
    expect(await cursors.read(), 'c-10');
    expect(await db.select(db.syncCursorRows).get(), hasLength(1),
        reason: '一个域一行，重放覆盖而不是追加');
  });

  test('applyAll 空批不写任何东西', () async {
    await applier.applyAll(const []);
    expect(await db.select(db.reminderItems).get(), isEmpty);
  });
}
