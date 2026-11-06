// #661：标签批量改写的 InMemory ≡ Drift 一致性。
//
// 本仓的老教训：「内存版绿、落盘版另一套行为」。所以标签的 rename/delete
// 两侧必须共用 kernel 的纯规则，并在这里把**派生标签、每条笔记的 tagNames、
// 每个智能文件夹的 filterJson** 三项一起快照比对。
import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LifeProductivityDb db;
  late DriftNoteRepository drift;
  late InMemoryNoteRepository memory;

  setUp(() {
    db = LifeProductivityDb(NativeDatabase.memory());
    drift = DriftNoteRepository(db);
    memory = InMemoryNoteRepository();
  });

  tearDown(() async => db.close());

  Future<void> seed(NoteRepository repo) async {
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertFolder(const NoteFolder(
      id: 'sf1',
      name: '重要事项',
      smart: true,
      filterJson: '{"tagNames":["重要"],"pinned":true}',
    ));
    await repo.upsertNote(const Note(
      id: 'n1',
      folderId: 'f1',
      title: '周报',
      tagNames: ['重要', '今天'],
    ));
    await repo.upsertNote(const Note(
      id: 'n2',
      folderId: 'f1',
      title: '买菜',
      tagNames: ['普通'],
    ));
    await repo.upsertNote(const Note(
      id: 'n3',
      folderId: 'f1',
      title: '体检',
      tagNames: ['重要'],
    ));
  }

  Future<Map<String, List<String>>> snap(NoteRepository repo) async {
    final tags = (await repo.watchTags().first).map((t) => t.name).toList();
    final notes = (await repo.watchNotes(folderId: null).first)
        .map((n) => '${n.id}:${n.tagNames.join(',')}')
        .toList()
      ..sort();
    final filters = (await repo.watchFolders().first)
        .where((f) => f.smart)
        .map((f) => '${f.id}:${f.filterJson}')
        .toList()
      ..sort();
    return {'tags': tags, 'notes': notes, 'filters': filters};
  }

  Future<void> expectSame(String reason) async {
    expect(await snap(drift), await snap(memory), reason: reason);
  }

  test('#661 起始状态两端一致', () async {
    await seed(drift);
    await seed(memory);
    await expectSame('种子落库后派生标签/条件一致');
  });

  test('#661 重命名：两端都改写全部笔记与智能文件夹条件', () async {
    await seed(drift);
    await seed(memory);
    await drift.renameTag('重要', '关键');
    await memory.renameTag('重要', '关键');

    await expectSame('InMemory ≡ Drift');
    final d = await snap(drift);
    expect(d['tags'], ['今天', '关键', '普通']);
    expect(d['notes'], ['n1:关键,今天', 'n2:普通', 'n3:关键']);
    expect(d['filters'], ['sf1:{"tagNames":["关键"],"pinned":true}'],
        reason: '只改 tagNames 键，pinned 条件必须原样带回');
  });

  test('#661 删除：两端都从全部笔记与条件移除', () async {
    await seed(drift);
    await seed(memory);
    await drift.deleteTag('重要');
    await memory.deleteTag('重要');

    await expectSame('InMemory ≡ Drift');
    final d = await snap(drift);
    expect(d['tags'], ['今天', '普通']);
    expect(d['notes'], ['n1:今天', 'n2:普通', 'n3:']);
    expect(d['filters'], ['sf1:{"tagNames":[],"pinned":true}'],
        reason: '条件留空数组（智能文件夹显示为空），不是放宽成全部');
  });

  test('#661 重命名到已存在名字时两端都合并去重', () async {
    await seed(drift);
    await seed(memory);
    await drift.renameTag('重要', '普通');
    await memory.renameTag('重要', '普通');

    await expectSame('InMemory ≡ Drift');
    final d = await snap(drift);
    expect(d['tags'], ['今天', '普通']);
    expect(d['notes'], ['n1:普通,今天', 'n2:普通', 'n3:普通']);
  });

  test('#661 空名/同名/不存在的标签是 no-op，两端都不发变更', () async {
    await seed(drift);
    await seed(memory);
    for (final repo in <NoteRepository>[drift, memory]) {
      await repo.renameTag('重要', '');
      await repo.renameTag('重要', '重要');
      await repo.deleteTag('不存在');
    }
    await expectSame('InMemory ≡ Drift');
    final d = await snap(drift);
    expect(d['tags'], ['今天', '普通', '重要']);
    expect(d['filters'], ['sf1:{"tagNames":["重要"],"pinned":true}']);
  });

  test('#661 软删笔记也一并改写，两端恢复后都不复活旧名', () async {
    await seed(drift);
    await seed(memory);
    for (final repo in <NoteRepository>[drift, memory]) {
      await repo.upsertNote(const Note(
        id: 'n4',
        folderId: 'f1',
        title: '旧档',
        tagNames: ['重要'],
      ));
      await repo.softDelete('n4');
    }
    for (final repo in <NoteRepository>[drift, memory]) {
      await repo.renameTag('重要', '关键');
      await repo.restore('n4');
    }
    await expectSame('InMemory ≡ Drift');
    for (final repo in <NoteRepository>[drift, memory]) {
      final n4 = (await repo.watchNotes(folderId: null).first)
          .firstWhere((n) => n.id == 'n4');
      expect(n4.tagNames, ['关键'],
          reason: '只改活笔记会让恢复的笔记复活出一个已不存在的标签');
    }
  });

  test('#661 Drift 侧把受影响行推入既有 outbox（不新增标签实体）', () async {
    await seed(drift);
    final outbox = DriftSyncOutbox(db);
    for (final e in await outbox.pending()) {
      await outbox.acknowledge(entityType: e.entityType, entityId: e.entityId);
    }
    expect(await outbox.pending(), isEmpty);

    await drift.renameTag('重要', '关键');
    final pending = await outbox.pending();
    final ids = pending.map((e) => e.entityId).toSet();
    expect(ids, containsAll(['n1', 'n3', 'sf1']),
        reason: '两条使用该标签的笔记 + 一个智能文件夹都要随既有渠道同步');
    expect(ids, isNot(contains('n2')), reason: '无关笔记不该被无谓推送');

    final n1 = pending.firstWhere((e) => e.entityId == 'n1');
    expect(n1.payload['tagNames'], ['关键', '今天']);
    final folder = pending.firstWhere((e) => e.entityId == 'sf1');
    expect(folder.payload['filterJson'], contains('关键'));
    expect(pending.every((e) => e.entityType == 'note' || e.entityType == 'folder'),
        isTrue, reason: '没有引入任何 tag 实体类型');
  });
}
