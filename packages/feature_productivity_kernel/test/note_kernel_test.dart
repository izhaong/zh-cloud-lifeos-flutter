import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// TC-NOTE-KR-101～106：记录内核模型与仓库契约（F-01；契约 §5）。
void main() {
  group('TC-NOTE-KR-101 文件夹树', () {
    test('建父文件夹与子文件夹，parentId 指向父；列表能还原两层', () async {
      final repo = InMemoryNoteRepository();
      final rootId =
          await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
      final childId = await repo.upsertFolder(
          NoteFolder(id: 'f2', name: '子', parentId: rootId));
      expect(childId, 'f2');

      final folders = await repo.watchFolders().first;
      final child = folders.firstWhere((f) => f.id == childId);
      expect(child.parentId, rootId, reason: 'parentId 指向父');

      // 还原两层：根层 1 条，父下 1 条
      final roots = folders.where((f) => f.parentId == null).toList();
      expect(roots.length, 1);
      final level2 =
          folders.where((f) => f.parentId == rootId).toList();
      expect(level2.length, 1, reason: '列表能还原两层');
    });
  });

  group('TC-NOTE-KR-102 正文两份', () {
    test('保存 Delta，bodyText 为纯文本，不含 JSON 括号噪声', () async {
      final repo = InMemoryNoteRepository();
      await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
      final id = await repo.upsertNote(const Note(
        id: 'n1',
        folderId: 'f1',
        title: '购物',
        bodyDelta: '{"ops":[{"insert":"买牛奶"},{"insert":"\\n"}]}',
      ));
      final notes = await repo.watchNotes().first;
      final note = notes.firstWhere((n) => n.id == id);
      expect(note.bodyText, '买牛奶\n');
      expect(note.bodyText.contains('{'), isFalse,
          reason: '不含 JSON 括号噪声');
    });
  });

  group('TC-NOTE-KR-103 置顶排序', () {
    test('两条笔记一条 pinned，置顶在前，其余按 sortOrder', () async {
      final repo = InMemoryNoteRepository();
      await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
      await repo.upsertNote(const Note(
        id: 'a',
        folderId: 'f1',
        title: '普通A',
        sortOrder: 0,
      ));
      await repo.upsertNote(const Note(
        id: 'b',
        folderId: 'f1',
        title: '置顶B',
        pinned: true,
        sortOrder: 5,
      ));
      final notes = await repo.watchNotes().first;
      expect(notes.first.id, 'b', reason: '置顶在前');
      expect(notes.last.id, 'a', reason: '其余按 sortOrder');
    });
  });

  group('TC-NOTE-KR-104 智能文件夹', () {
    test('条件 tagNames=工作，只命中带该标签的未删除笔记', () async {
      final repo = InMemoryNoteRepository();
      await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
      await repo.upsertNote(const Note(
        id: 'tagged',
        folderId: 'f1',
        title: '带标签',
        tagNames: ['工作'],
      ));
      await repo.upsertNote(const Note(
        id: 'plain',
        folderId: 'f1',
        title: '无标签',
      ));
      await repo.upsertFolder(const NoteFolder(
        id: 'smart1',
        name: '智能',
        smart: true,
        filterJson: '{"tagNames":["工作"]}',
      ));
      final hits = await repo.watchNotes(folderId: 'smart1').first;
      expect(hits.length, 1, reason: '只命中带该标签的');
      expect(hits.first.id, 'tagged');

      // 删除后不再命中（未删除笔记才进智能文件夹）
      await repo.softDelete('tagged');
      final afterDelete = await repo.watchNotes(folderId: 'smart1').first;
      expect(afterDelete, isEmpty, reason: '已删笔记不进智能文件夹');
    });
  });

  group('TC-NOTE-KR-105 清单计数', () {
    test('Delta 含 2 条清单勾 1 条，checklistTotal=2 done=1', () async {
      final repo = InMemoryNoteRepository();
      await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
      const delta =
          '{"ops":[{"insert":"任务1","attributes":{"list":"unchecked"}},{"insert":"任务2","attributes":{"list":"checked"}}]}';
      final id = await repo.upsertNote(const Note(
        id: 'n1',
        folderId: 'f1',
        title: '清单',
        bodyDelta: delta,
      ));
      final notes = await repo.watchNotes().first;
      final note = notes.firstWhere((n) => n.id == id);
      expect(note.checklistTotal, 2);
      expect(note.checklistDone, 1);
    });
  });

  group('TC-NOTE-KR-106 软删 30 天', () {
    test('删除后 31 天的被硬删，29 天的还在', () async {
      final repo = InMemoryNoteRepository();
      await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
      await repo.upsertNote(const Note(
          id: 'old', folderId: 'f1', title: '旧的'));
      await repo.upsertNote(const Note(
          id: 'new', folderId: 'f1', title: '新的'));

      await repo.softDelete('old');
      await repo.softDelete('new');

      // 时钟拨动：old 的删除时间回拨 31 天（超窗），new 保持 0 天（窗内）
      final now = DateTime.now();
      repo.nowForTest = now;
      repo.debugAgeDeletion('old', const Duration(days: 31));
      final removed = await repo.purgeExpired();
      expect(removed, 1, reason: '31 天的被硬删');

      // 29 天的还在：窗内软删行可恢复（未被物理删除）
      await repo.restore('new');
      final revived = await repo.watchNotes().first;
      expect(revived.any((n) => n.id == 'old'), isFalse,
          reason: '31 天的不在了');
      expect(revived.any((n) => n.id == 'new'), isTrue,
          reason: '29 天的还在（可恢复）');
    });
  });
}
