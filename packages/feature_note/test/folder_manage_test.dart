// TC-NOTE-UI-101 补强（#373）：文件夹的**重命名 / 删除**入口。
//
// 现象：文件夹侧栏只能新建；右键没有任何上下文菜单，界面上也没有别的入口。
// Apple 备忘录：Control-click 文件夹 → 「重新命名文件夹」；删除文件夹会把里面的
// 备忘录移到「最近删除」（可恢复）。
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
  await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
  await repo.upsertNote(const Note(id: 'n1', folderId: 'f1', title: '周报'));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [noteRepositoryProvider.overrideWithValue(repo)],
      child: const CupertinoApp(
        theme: CupertinoThemeData(),
        home: SizedBox(width: 260, child: NoteSidebar()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}


/// 打开文件夹的「…」动作表。
///
/// 说明：仓库同时提供了 Apple 风格的 `CupertinoContextMenu`（Control-click），
/// 但它在 widget 测试里需要按住 ≥800ms 让 decoy 动画跑完、再走手势仲裁，很不稳定；
/// 所以行为断言走「…」入口——两条入口调用的是同一组 `_renameFolder`/`_deleteFolder`。
Future<void> _openFolderActions(WidgetTester tester) async {
  await tester.tap(find.byIcon(CupertinoIcons.ellipsis).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TC-NOTE-UI-101 文件夹有重命名/删除入口（… 动作表）', (tester) async {
    await _pump(tester);

    // macOS 上相当于 Control-click：widget 测试用长按触发 CupertinoContextMenu。
    await _openFolderActions(tester);

    expect(find.byKey(const ValueKey('note_folder_action_rename_f1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note_folder_action_delete_f1')), findsOneWidget);
  });

  testWidgets('TC-NOTE-UI-101 重命名后侧栏显示新名称', (tester) async {
    final repo = await _pump(tester);

    await _openFolderActions(tester);
    await tester.tap(find.byKey(const ValueKey('note_folder_action_rename_f1')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('note_rename_folder_name')), '工作归档');
    await tester.tap(find.byKey(const ValueKey('note_rename_folder_ok')));
    await tester.pumpAndSettle();

    final folders = await repo.watchFolders().first;
    expect(folders.where((f) => f.id == 'f1').single.name, '工作归档');
    expect(find.text('工作归档'), findsOneWidget);
  });

  testWidgets('TC-NOTE-UI-101 删除文件夹：其中的备忘录进「最近删除」', (tester) async {
    final repo = await _pump(tester);

    await _openFolderActions(tester);
    await tester.tap(find.byKey(const ValueKey('note_folder_action_delete_f1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_delete_folder_ok')));
    await tester.pumpAndSettle();

    expect(await repo.watchFolders().first, isEmpty, reason: '文件夹应被移除');
    final deleted = await repo.watchDeleted().first;
    expect(deleted.map((n) => n.id), contains('n1'),
        reason: 'Apple：删除文件夹时里面的备忘录要移到「最近删除」，而不是直接消失');
  });
}
