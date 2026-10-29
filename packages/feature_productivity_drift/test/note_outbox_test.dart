// TC-NOTE-SYNC-101 前置（#413）：备忘录的本地写入必须进发件箱。
//
// 此前 note 侧 0 处写 outbox —— `RestSyncPort` 没有数据源，登录后备忘录不上传。
import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LifeProductivityDb db;
  late DriftNoteRepository repo;
  late DriftSyncOutbox outbox;

  setUp(() {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftNoteRepository(db);
    outbox = DriftSyncOutbox(db);
  });

  tearDown(() async => db.close());

  test('#413 新建备忘录 → 发件箱出现 note/upsert', () async {
    await repo.upsertNote(const Note(
      id: 'n1',
      folderId: 'f1',
      title: '周报',
      bodyDelta: '{"ops":[]}',
    ));

    final pending = await outbox.pending();
    expect(pending, hasLength(1));
    final entry = pending.single;
    expect(entry.entityType, 'note');
    expect(entry.entityId, 'n1');
    expect(entry.operation, 'upsert');
    expect(entry.payload['title'], '周报');
    expect(entry.payload['id'], 'n1');
    expect(entry.clientMutationId, startsWith('note-n1-'));
  });

  test('#413 软删 → operation=delete，载荷带 deletedAt', () async {
    await repo.upsertNote(const Note(
      id: 'n2',
      folderId: 'f1',
      title: '待删',
      bodyDelta: '',
    ));
    await repo.softDelete('n2');

    final pending = await outbox.pending();
    expect(pending, hasLength(1),
        reason: '同实体未推条目应合并成一条（幂等键沿用）');
    expect(pending.single.operation, 'delete');
    expect(pending.single.payload['deletedAt'], isNotNull);
  });

  test('#413 恢复 → 回到 upsert', () async {
    await repo.upsertNote(const Note(
      id: 'n3',
      folderId: 'f1',
      title: '恢复我',
      bodyDelta: '',
    ));
    await repo.softDelete('n3');
    await repo.restore('n3');

    final pending = await outbox.pending();
    expect(pending.single.operation, 'upsert');
    expect(pending.single.payload['deletedAt'], isNull);
  });

  test('#413 文件夹新建/删除同样进发件箱', () async {
    await repo.upsertFolder(const NoteFolder(id: 'f2', name: '工作'));
    var pending = await outbox.pending();
    expect(pending.single.entityType, 'folder');
    expect(pending.single.operation, 'upsert');
    expect(pending.single.payload['name'], '工作');

    // 清空队列再看删除
    for (final e in await outbox.pending()) {
      await outbox.acknowledge(
        entityType: e.entityType,
        entityId: e.entityId,
      );
    }
    await repo.deleteFolder('f2');
    pending = await outbox.pending();
    expect(pending.single.operation, 'delete');
    expect(pending.single.entityId, 'f2');
  });

  test('#413 锁定备忘录上传的是密文，不是明文（与 #395 一致）', () async {
    final sealed = NoteLockCodec.seal('{"ops":[{"insert":"秘密\\n"}]}', 'pw');
    await repo.upsertNote(Note(
      id: 'n4',
      folderId: 'f1',
      title: '锁定的',
      bodyDelta: sealed,
      locked: true,
    ));

    final payload = (await outbox.pending()).single.payload;
    expect(payload['bodyDelta'], sealed);
    expect(payload['bodyDelta'].toString().contains('秘密'), isFalse);
    expect(payload['locked'], isTrue);
  });
}
