import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// V16：任务创建时间的本地落库与入站覆盖（flutter #278，前置 service #539）。
///
/// 三条形各自钉住：① 本机新建即有创建时间（否则「按创建日期」这档对新任务无意义）；
/// ② 全量回写式编辑不改它；③ 入站带 createTime 时以服务端为准、不带时不抹平。
void main() {
  late LifeProductivityDb db;
  late DriftReminderRepository repo;

  setUp(() {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftReminderRepository(db);
  });
  tearDown(() async => db.close());

  Future<ReminderItem?> itemOf(String id) async {
    for (final i in await repo.watchItems(listId: 'list.a').first) {
      if (i.id == id) return i;
    }
    return null;
  }

  Future<void> seedList() async =>
      repo.upsertList(const ReminderList(id: 'list.a', title: '列表A'));

  SyncIncomingChange taskChange(Map<String, dynamic> payload) =>
      SyncIncomingChange(
        entityType: 'task',
        entityId: 'open1',
        operation: 'upsert',
        payload: payload,
      );

  test('V16 建列：reminder_items 有 created_at，schemaVersion 到 16', () async {
    final cols = await db
        .customSelect('PRAGMA table_info(reminder_items)')
        .get();
    expect(cols.map((r) => r.data['name']), contains('created_at'));
    expect(db.schemaVersion, 16, reason: 'V16 给 reminder_items 加 created_at');
  });

  test('本机新建即落创建时间；编辑不改它', () async {
    await seedList();
    await repo.upsertItem(
      const ReminderItem(id: 'open1', listId: 'list.a', title: '买牛奶'),
    );
    final created = (await itemOf('open1'))!.createdAt;
    expect(created, isNotNull, reason: '新任务没有创建时间 ⇒ 「按创建日期」这档对它失效');

    await repo.upsertItem(
      const ReminderItem(
        id: 'open1',
        listId: 'list.a',
        title: '买牛奶2',
        createdAt: null,
      ),
    );
    final afterEdit = await itemOf('open1');
    expect(afterEdit!.title, '买牛奶2');
    expect(afterEdit.createdAt, created, reason: '编辑不许抹平或改写创建时间');
  });

  test('入站 createTime 覆盖本地；不带这一键时保留本地值', () async {
    await seedList();
    await repo.upsertItem(
      const ReminderItem(id: 'open1', listId: 'list.a', title: '买牛奶'),
    );
    final local = (await itemOf('open1'))!.createdAt!;

    final server = DateTime(2019, 5, 6, 7, 8);
    await repo.applyAll([
      taskChange({
        'listId': 'list.a',
        'title': '买牛奶',
        'createTime': server.millisecondsSinceEpoch,
      }),
    ]);
    expect((await itemOf('open1'))!.createdAt, server);

    await repo.applyAll([
      taskChange({'listId': 'list.a', 'title': '买牛奶改名'}),
    ]);
    final kept = await itemOf('open1');
    expect(kept!.title, '买牛奶改名');
    expect(kept.createdAt, server, reason: '老服务端不带 createTime ⇒ 不得抹成 null');
    expect(kept.createdAt, isNot(local));
  });

  test('snake 拼写 create_time 同样读得到', () async {
    await seedList();
    await repo.upsertItem(
      const ReminderItem(id: 'open1', listId: 'list.a', title: '买牛奶'),
    );
    final server = DateTime(2018, 1, 2, 3, 4);
    await repo.applyAll([
      taskChange({
        'listId': 'list.a',
        'title': '买牛奶',
        'create_time': server.millisecondsSinceEpoch,
      }),
    ]);
    expect((await itemOf('open1'))!.createdAt, server);
  });
}
