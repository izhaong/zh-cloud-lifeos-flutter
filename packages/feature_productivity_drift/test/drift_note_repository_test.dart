import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// #280：记录本机持久化的 Drift 契约。
///
/// 这些断言与 `InMemoryNoteRepository` 的行为逐条对齐（归一/排序/软删恢复/
/// 回收窗/搜索/智能文件夹），保证「内存版绿」不会掩盖落盘版的偏差。
void main() {
  late LifeProductivityDb db;
  late DriftNoteRepository repo;

  setUp(() {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftNoteRepository(db);
  });

  tearDown(() async => db.close());

  Note note(String id, {String folder = 'f1', String title = '标题', String text = '正文', bool pinned = false, String tags = ''}) =>
      Note(
        id: id,
        folderId: folder,
        title: title,
        bodyDelta: '{"ops":[{"insert":"$text\\n"}]}',
        pinned: pinned,
        tagNames: tags.isEmpty ? const [] : tags.split(','),
        clientUpdatedAt: DateTime(2026, 10, 20).millisecondsSinceEpoch,
      );

  test('落库后重新打开库仍能读到（真持久化，不是内存态）', () async {
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '默认'));
    await repo.upsertNote(note('n1', title: '持久化验证'));

    final reopened = DriftNoteRepository(db);
    final notes = await reopened.watchNotes().first;
    expect(notes.single.title, '持久化验证');
  });

  test('保存归一：正文抽纯文本（TC-NOTE-KR-102）', () async {
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '默认'));
    await repo.upsertNote(note('n1', text: '正文一行'));
    final n = (await repo.watchNotes().first).single;
    expect(n.bodyText.trim(), '正文一行');
  });

  test('软删进「最近删除」、恢复回来（TC-NOTE-UI-114）', () async {
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '默认'));
    await repo.upsertNote(note('n1'));
    await repo.softDelete('n1');
    expect(await repo.watchNotes().first, isEmpty);
    expect((await repo.watchDeleted().first).single.id, 'n1');

    await repo.restore('n1');
    expect((await repo.watchNotes().first).single.id, 'n1');
    expect(await repo.watchDeleted().first, isEmpty);
  });

  test('全量回写不会把软删的笔记「复活」', () async {
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '默认'));
    await repo.upsertNote(note('n1'));
    await repo.softDelete('n1');

    await repo.upsertNote(note('n1', title: '改标题'));
    expect(await repo.watchNotes().first, isEmpty, reason: '仍是删除态');
    expect((await repo.watchDeleted().first).single.title, '改标题');
  });

  test('回收窗超期硬删（>30 天）', () async {
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '默认'));
    await repo.upsertNote(note('old'));
    repo.nowForTest = DateTime(2026, 10, 1);
    await repo.softDelete('old');
    repo.nowForTest = DateTime(2026, 11, 15); // 45 天后
    final removed = await repo.purgeExpired();
    expect(removed, 1);
    expect(await repo.watchDeleted().first, isEmpty);
  });

  test('搜索只看未删未锁的标题/正文', () async {
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '默认'));
    await repo.upsertNote(note('n1', title: '周报', text: '本周进展'));
    await repo.upsertNote(note('n2', title: '购物', text: '牛奶'));

    expect((await repo.search('周报')).single.id, 'n1');
    expect((await repo.search('牛奶')).single.id, 'n2');
    expect(await repo.search('不存在'), isEmpty);
  });

  test('排序：置顶优先 → sortOrder → id（TC-NOTE-KR-103）', () async {
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '默认'));
    await repo.upsertNote(note('a', title: 'A'));
    await repo.upsertNote(note('b', title: 'B', pinned: true));
    await repo.upsertNote(note('c', title: 'C'));

    expect(
      (await repo.watchNotes().first).map((n) => n.id).toList(),
      ['b', 'a', 'c'],
    );
  });

  test('智能文件夹按 tagNames 过滤', () async {
    await repo.upsertFolder(const NoteFolder(
      id: 'smart1',
      name: '工作',
      smart: true,
      filterJson: '{"tagNames":["工作"]}',
    ));
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '默认'));
    await repo.upsertNote(note('n1', title: '工作稿', tags: '工作'));
    await repo.upsertNote(note('n2', title: '私事'));

    final hits = await repo.watchNotes(folderId: 'smart1').first;
    expect(hits.single.id, 'n1');
  });

  test('标签从存活笔记派生（去重、排序）', () async {
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '默认'));
    await repo.upsertNote(note('n1', tags: '工作,重要'));
    await repo.upsertNote(note('n2', tags: '工作'));

    final tags = await repo.watchTags().first;
    expect(tags.map((t) => t.name).toList(), ['工作', '重要']);
  });
}
