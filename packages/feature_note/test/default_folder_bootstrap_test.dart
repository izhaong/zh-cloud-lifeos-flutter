import 'package:feature_note/feature_note.dart';
import 'package:flutter_test/flutter_test.dart';

/// parity#155：空库首启必须有可写文件夹，且「新建文件夹」是幂等的。
///
/// 之前空库点「新建备忘录 / 快速记录」只弹「先新建一个文件夹」，而界面
/// 没有任何建文件夹入口 → 第一条笔记永远创建不出来。
void main() {
  test('空库兜底建「备忘录」文件夹', () async {
    final repo = InMemoryNoteRepository();
    expect(await repo.watchFolders().first, isEmpty);

    final id = await ensureDefaultNoteFolder(repo);
    final folders = await repo.watchFolders().first;

    expect(folders.map((f) => f.id), contains(id));
    expect(folders.single.name, '备忘录');
    expect(folders.single.smart, isFalse);
  });

  test('已有文件夹时不重复创建（幂等）', () async {
    final repo = InMemoryNoteRepository();
    final first = await ensureDefaultNoteFolder(repo);
    final second = await ensureDefaultNoteFolder(repo);

    expect(second, first);
    expect((await repo.watchFolders().first).length, 1);
  });

  test('只挡住智能文件夹：已有普通文件夹时直接复用', () async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f-smart', name: '工作', smart: true));
    final plain = await repo.upsertFolder(
      const NoteFolder(id: 'f-plain', name: '资料'),
    );

    expect(await ensureDefaultNoteFolder(repo), plain);
  });
}
