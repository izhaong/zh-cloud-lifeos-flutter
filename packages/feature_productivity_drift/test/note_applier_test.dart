// TC-NOTE-SYNC-101 落库侧（#414）：服务端下推的变更要落到本地，且**不得回写发件箱**。
//
// 这条约束是 task 侧踩过的坑：pull 落库若走 upsertNote，会顺手 enqueue 一条出站变更，
// push 再推回服务端 → 无限往返。
import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

SyncIncomingChange _noteChange({
  required String id,
  String operation = 'upsert',
  Map<String, dynamic> payload = const {},
}) =>
    SyncIncomingChange(
      entityType: 'note',
      entityId: id,
      operation: operation,
      payload: payload,
    );

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

  test('#414 入站 upsert 落库，且**不**产生出站变更', () async {
    await repo.applyAll([
      _noteChange(id: 'n1', payload: {
        'folderId': 'f1',
        'title': '服务端来的',
        'bodyDelta': '{"ops":[{"insert":"hi\\n"}]}',
        'bodyText': 'hi',
        'clientUpdatedAt': 1000,
      }),
    ]);

    final notes = await repo.watchNotes().first;
    expect(notes.single.title, '服务端来的');
    expect(notes.single.bodyText, 'hi');
    expect(await outbox.pending(), isEmpty,
        reason: '入站落库回写发件箱会造成 pull→push 无限往返');
  });

  test('#414 入站 delete → 进「最近删除」而不是硬删', () async {
    await repo.applyAll([
      _noteChange(id: 'n2', payload: {'folderId': 'f1', 'title': '待删'}),
    ]);
    await repo.applyAll([
      _noteChange(id: 'n2', operation: 'delete', payload: {'deletedAt': 5000}),
    ]);

    expect(await repo.watchNotes().first, isEmpty, reason: '默认视图不再显示');
    final deleted = await repo.watchDeleted().first;
    expect(deleted.single.id, 'n2');
    expect(deleted.single.deletedAt, isNotNull);
    expect(await outbox.pending(), isEmpty);
  });

  test('#414 文件夹 upsert / delete', () async {
    await repo.applyAll([
      const SyncIncomingChange(
        entityType: 'folder',
        entityId: 'f9',
        operation: 'upsert',
        payload: {'name': '服务端文件夹', 'sortOrder': 3},
      ),
    ]);
    final folders = await repo.watchFolders().first;
    expect(folders.single.name, '服务端文件夹');

    await repo.applyAll([
      const SyncIncomingChange(
        entityType: 'folder',
        entityId: 'f9',
        operation: 'delete',
        payload: {},
      ),
    ]);
    final roots = await repo.watchFolders().first;
    expect(roots.where((f) => f.id == 'f9'), isEmpty);
    expect(await outbox.pending(), isEmpty);
  });

  test('#414 未知实体类型被忽略，不影响同批其它变更', () async {
    await repo.applyAll([
      const SyncIncomingChange(
        entityType: 'mystery',
        entityId: 'x1',
        operation: 'upsert',
        payload: {},
      ),
      _noteChange(id: 'n3', payload: {'folderId': 'f1', 'title': '照常落库'}),
    ]);
    final notes = await repo.watchNotes().first;
    expect(notes.single.id, 'n3');
  });
}
