import 'package:drift/native.dart';

import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutter#144 / TC-SYNC-106 客户端剩余半边：清单（`list`）与手动分区
/// （`task_section`）实体的入站落库与出站登记。
///
/// 标签不是服务端实体（`LifeosTaskSyncCodec` 只有 task/list/task_section），
/// 本地标签是 `reminder_items.tags` 的 JSON 数组、随任务载荷走，故不在此测。
void main() {
  late LifeProductivityDb db;
  late DriftReminderRepository repo;
  late DriftSyncOutbox outbox;

  setUp(() async {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftReminderRepository(db);
    outbox = DriftSyncOutbox(db);
  });

  tearDown(() async => db.close());

  Future<ReminderList?> listOf(String id) async {
    for (final l in await repo.watchLists().first) {
      if (l.id == id) return l;
    }
    return null;
  }

  SyncIncomingChange listChange(String entityId, Map<String, dynamic> payload,
          {String operation = 'upsert'}) =>
      SyncIncomingChange(
        entityType: 'list',
        entityId: entityId,
        operation: operation,
        payload: payload,
      );

  SyncIncomingChange sectionChange(
    String entityId,
    Map<String, dynamic> payload, {
    String operation = 'upsert',
  }) =>
      SyncIncomingChange(
        entityType: 'task_section',
        entityId: entityId,
        operation: operation,
        payload: payload,
      );

  group('TC-SYNC-106 清单入站落库', () {
    test('V14：对端新建的清单在本机出现并记住 remoteId', () async {
      await repo.applyAll([
        listChange('9001', {
          'id': 9001,
          'name': '对端清单',
          'color': 0xFF34C759,
          'type': 'standard',
          'isSmart': false,
          'sortOrder': 5,
        }),
      ]);

      final l = await listOf('9001');
      expect(l, isNotNull, reason: '对端新建的清单要在本机出现（共享同一套列表）');
      expect(l!.title, '对端清单');
      expect(l.colorArgb, 0xFF34C759);
      expect(l.sortOrder, 5);
      expect(l.remoteId, '9001');
      expect(db.schemaVersion, 23,
          reason: 'V14 给 reminder_lists 加 remote_id 列（flutter#144）');
    });

    test('同一清单重复下推只有一行（幂等）', () async {
      final c = listChange('9001', {'id': 9001, 'name': '对端清单'});
      await repo.applyAll([c]);
      await repo.applyAll([c]);

      final rows = (await repo.watchLists().first)
          .where((l) => l.remoteId == '9001')
          .toList();
      expect(rows, hasLength(1));
    });

    test('改名下推按 remoteId 命中原行，且不抹掉已落地的分区', () async {
      await repo.applyAll([listChange('9001', {'id': 9001, 'name': '旧名'})]);
      await repo.applyAll([
        sectionChange('7001', {'id': 7001, 'listId': '9001', 'name': '水果'}),
      ]);
      await repo.applyAll([listChange('9001', {'id': 9001, 'name': '新名'})]);

      final l = await listOf('9001');
      expect(l!.title, '新名');
      expect(l.sections.map((s) => s.title), contains('水果'));
    });

    test('清单删除下推：清单行消失，条目随清单进回收窗', () async {
      await repo.applyAll([listChange('9001', {'id': 9001, 'name': '对端清单'})]);
      await repo.upsertItem(
          const ReminderItem(id: 'i1', listId: '9001', title: '买牛奶'));

      await repo.applyAll([
        listChange('9001', {'id': 9001}, operation: 'delete'),
      ]);

      expect(await listOf('9001'), isNull);
      final rows = await db.select(db.reminderItems).get();
      expect(rows.single.deletedAt, isNotNull,
          reason: '与本地 deleteList 同口径：条目软删进回收窗，不留孤儿');
    });
  });

  group('TC-SYNC-106 清单出站登记', () {
    test('upsertList 登记一条 list upsert，载荷用服务端键名', () async {
      await repo.upsertList(const ReminderList(id: 'list.personal', title: '个人'));

      final e = (await outbox.pending())
          .firstWhere((x) => x.entityType == 'list');
      expect(e.entityId, 'list.personal', reason: '未回填 remoteId 前用本地 id 上送');
      expect(e.operation, 'upsert');
      expect(e.payload['name'], '个人');
      expect(e.payload['type'], 'standard');
      expect(e.clientMutationId, startsWith('list-list.personal-'));
      expect(e.clientUpdatedAt, greaterThan(0));
    });

    test('deleteList 记清单 delete，级联条目各记自己的 task delete', () async {
      await repo.upsertList(const ReminderList(id: 'list.personal', title: '个人'));
      await repo.upsertItem(const ReminderItem(
          id: 'i1', listId: 'list.personal', title: '买牛奶'));

      await repo.deleteList('list.personal');

      final pending = await outbox.pending();
      expect(
          pending.where((e) => e.entityType == 'list' && e.operation == 'delete'),
          hasLength(1),
          reason: '清单本体要出站记删除');
      expect(pending.where((e) => e.entityType == 'task'), hasLength(1),
          reason: '级联条目记自己的 task delete，不重复记清单');
    });
  });

  group('TC-SYNC-106 分区入站落库', () {
    test('对端新建分区落进归属清单，并记住 remoteId', () async {
      await repo.applyAll([listChange('9001', {'id': 9001, 'name': '对端清单'})]);
      await repo.applyAll([
        sectionChange('7001',
            {'id': 7001, 'listId': '9001', 'name': '水果', 'sortOrder': 0}),
      ]);

      final l = await listOf('9001');
      expect(l!.sections, hasLength(1));
      expect(l.sections.single.title, '水果');
      expect(l.sections.single.remoteId, '7001',
          reason: '再次下推要能按 remoteId 命中原分区，而不是新增第二条');
    });

    test('分区改名按 remoteId 命中原分区，不新增第二条', () async {
      await repo.applyAll([listChange('9001', {'id': 9001, 'name': '对端清单'})]);
      await repo.applyAll([
        sectionChange('7001', {'id': 7001, 'listId': '9001', 'name': '水果'}),
      ]);
      await repo.applyAll([
        sectionChange('7001', {'id': 7001, 'listId': '9001', 'name': '蔬菜'}),
      ]);

      final l = await listOf('9001');
      expect(l!.sections, hasLength(1));
      expect(l.sections.single.title, '蔬菜');
    });

    test('分区删除下推：分区消失且挂靠条目回落「未分区」', () async {
      await repo.applyAll([listChange('9001', {'id': 9001, 'name': '对端清单'})]);
      await repo.applyAll([
        sectionChange('7001', {'id': 7001, 'listId': '9001', 'name': '水果'}),
      ]);
      await repo.upsertItem(const ReminderItem(
          id: 'i1', listId: '9001', title: '苹果', sectionId: '7001'));

      await repo.applyAll([
        sectionChange('7001', {'id': 7001, 'listId': '9001'},
            operation: 'delete'),
      ]);

      final l = await listOf('9001');
      expect(l!.sections, isEmpty);
      final rows = await db.select(db.reminderItems).get();
      expect(rows.single.sectionId, isNull, reason: '级联：条目兜底未分区');
    });

    test('归属清单还没到时分区下推被跳过，不炸整批', () async {
      await repo.applyAll([
        sectionChange('7001', {'id': 7001, 'listId': '9999', 'name': '水果'}),
      ]);
      expect(await outbox.pending(), isEmpty);
    });
  });

  group('TC-SYNC-106 出站/入站隔离', () {
    test('入站落库不进发件箱（防两端自己造往返风暴）', () async {
      await repo.applyAll([
        listChange('9001', {'id': 9001, 'name': '对端清单'}),
        sectionChange('7001', {'id': 7001, 'listId': '9001', 'name': '水果'}),
      ]);
      expect(await outbox.pending(), isEmpty);
    });

    test('upsertSection 登记 task_section，listId 发清单的服务端 ID', () async {
      await repo.applyAll([listChange('9001', {'id': 9001, 'name': '对端清单'})]);
      await repo.upsertSection(
        listId: '9001',
        section: const ReminderSection(id: 'sec_local', title: '水果'),
      );

      final e = (await outbox.pending())
          .firstWhere((x) => x.entityType == 'task_section');
      expect(e.operation, 'upsert');
      expect(e.payload['name'], '水果');
      expect(e.payload['listId'], '9001');
    });

    test('deleteSection 记 task_section delete，条目回落各记 task', () async {
      await repo.upsertList(const ReminderList(id: 'list.personal', title: '个人'));
      await repo.upsertSection(
        listId: 'list.personal',
        section: const ReminderSection(id: 'sec_1', title: '水果'),
      );
      await repo.upsertItem(const ReminderItem(
          id: 'i1', listId: 'list.personal', title: '苹果', sectionId: 'sec_1'));

      await repo.deleteSection(listId: 'list.personal', sectionId: 'sec_1');

      final pending = await outbox.pending();
      expect(
          pending.where(
              (e) => e.entityType == 'task_section' && e.operation == 'delete'),
          hasLength(1));
      expect((await listOf('list.personal'))!.sections, isEmpty);
    });

    test('清单载荷往返不丢档位', () {
      const src = ReminderList(
        id: 'l1',
        title: '采购',
        colorArgb: 0xFF34C759,
        sortOrder: 3,
        listType: ReminderListType.grocery,
        remoteId: '9001',
      );
      final payload = listSyncPayload(src);
      expect(payload['id'], '9001', reason: '有 remoteId 就发服务端 ID');

      final back = reminderListFromSyncPayload(payload, entityId: '9001');
      expect(back.title, src.title);
      expect(back.colorArgb, src.colorArgb);
      expect(back.sortOrder, src.sortOrder);
      expect(back.listType, ReminderListType.grocery);
      expect(back.remoteId, '9001');
    });
  });
}
