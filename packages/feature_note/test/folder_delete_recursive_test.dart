// #379：删除文件夹必须**递归**——三层嵌套下，父文件夹删掉后：
//  1. 所有后代文件夹都要消失（否则留下 parentId 指向已删行的孤儿，界面上看不见但数据还在）；
//  2. 后代文件夹里的笔记必须进「最近删除」（否则数据在、任何视图都看不到，比删掉更糟）。
//
// Apple 备忘录：删除文件夹会把整个子树连同里面的备忘录一起放进「最近删除」，可整体恢复。
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<InMemoryNoteRepository> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = InMemoryNoteRepository();
  // 三层：A > B > C，每层各一条笔记
  await repo.upsertFolder(const NoteFolder(id: 'A', name: '项目'));
  await repo.upsertFolder(const NoteFolder(id: 'B', name: '子项目', parentId: 'A'));
  await repo.upsertFolder(
      const NoteFolder(id: 'C', name: '更细', parentId: 'B'));
  await repo.upsertNote(const Note(id: 'nA', folderId: 'A', title: '在 A'));
  await repo.upsertNote(const Note(id: 'nB', folderId: 'B', title: '在 B'));
  await repo.upsertNote(const Note(id: 'nC', folderId: 'C', title: '在 C'));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [noteRepositoryProvider.overrideWithValue(repo)],
      child: const CupertinoApp(
        home: SizedBox(width: 260, child: NoteSidebar()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _deleteFolder(WidgetTester tester, String folderId) async {
  await tester.tap(find.byKey(ValueKey('note_folder_more_$folderId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('note_folder_action_delete_$folderId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('note_delete_folder_ok')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('#379 删父文件夹：三层文件夹全部消失', (tester) async {
    final repo = await _pump(tester);
    await _deleteFolder(tester, 'A');

    final folders = await repo.watchFolders().first;
    expect(folders, isEmpty,
        reason: 'B、C 会变成 parentId 指向已删行的孤儿：侧栏按 parentId==null 取根，'
            '它们从此看不见，但数据还在库里');
  });

  testWidgets('#379 删父文件夹：三层里的笔记都进「最近删除」', (tester) async {
    final repo = await _pump(tester);
    await _deleteFolder(tester, 'A');

    final deleted = await repo.watchDeleted().first;
    expect(deleted.map((n) => n.id).toSet(), {'nA', 'nB', 'nC'},
        reason: '子文件夹里的笔记不能留在原处——它们既不在任何可见文件夹里，'
            '也不在「最近删除」里，等于静默丢失');
  });
}
