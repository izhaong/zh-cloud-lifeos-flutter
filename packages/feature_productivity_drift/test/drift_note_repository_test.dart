import 'dart:io';

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

  test('落盘后**关库重开同一个文件**仍能读到（真持久化，等价客户端重启）', () async {
    // 审查指出：早先这版只是对同一个 NativeDatabase.memory() 实例再建一次
    // Repository，那证明的是「仓储能读同一连接」，不是持久化。改成文件库 +
    // 关库重开，才等价「客户端重启后还在」（#305 的 TC-NOTE-UI-116）。
    final dir = await Directory.systemTemp.createTemp('note_persist');
    final file = File('${dir.path}/notes.db');
    addTearDown(() => dir.deleteSync(recursive: true));

    final first = LifeProductivityDb(NativeDatabase(file));
    final firstRepo = DriftNoteRepository(first);
    await firstRepo.upsertFolder(const NoteFolder(id: 'f1', name: '默认'));
    await firstRepo.upsertNote(
      note('n1', title: '持久化验证', text: '正文一行'),
    );
    // #361：并行负载下（`melos run verify` 里 analyze 与 test 同时跑）这里偶发
    // `CouldNotRollBackException: … database has already been closed`——
    // drift 的内部事务/通知微任务还没落完，close() 就撞上回滚。
    // 关库前先把挂起的微任务冲干净（这个测试要证明的是「重开后还能读到」，
    // 不是「close 的时序鲁棒性」）。
    await pumpEventQueue();
    await first.close();

    final second = LifeProductivityDb(NativeDatabase(file));
    addTearDown(second.close);
    final notes = await DriftNoteRepository(second).watchNotes().first;
    expect(notes.single.title, '持久化验证');
    expect(
      notes.single.bodyText.trim(),
      '正文一行',
      reason: '预期是「正文可读」，不能只断言标题还在',
    );
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

  test('搜索大小写不敏感，与内存仓库同口径（#670）', () async {
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '默认'));
    await repo.upsertNote(note('n1', title: 'Buy Milk', text: '两盒'));
    await repo.upsertNote(note('n2', title: '周报', text: 'Weekly REPORT'));

    expect((await repo.search('MILK')).single.id, 'n1');
    expect((await repo.search('report')).single.id, 'n2');
    expect(await repo.search('cheese'), isEmpty);
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
