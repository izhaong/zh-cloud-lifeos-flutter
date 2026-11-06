// TC-NOTE-UI-121（#661）：标签的**管理面**——创建 / 重命名 / 删除。
//
// 金标准（Apple 备忘录使用手册「在 Mac 上的『备忘录』中使用标签」）：
//   - 创建：在备忘录正文键入 `#` + 单词，或从建议标签列表选取；没有「新建空
//     标签」界面。本仓对应编辑器标签输入（TC-NOTE-UI-106）。
//   - 重命名：Control-click 边栏标签 →「重新命名标签」；「使用了该标签的所有
//     备忘录和智能文件夹都会更新」。
//   - 删除：Control-click 边栏标签 →「删除标签」；「标签会从使用了这些标签的
//     所有备忘录和智能文件夹中删除」。
//   - 「如果将标签从所有使用它的备忘录移除，该标签也会从『标签』中移除」——
//     所以标签是从笔记 tagNames 派生的视图，不该为它建独立实体。
//
// 判据只看仓库真值与 provider 状态：批量改写必须落到每条笔记、每个智能文件夹
// 条件、以及侧栏派生行；不做「按钮点了就算数」的恒真断言。
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(InMemoryNoteRepository, ProviderContainer)> pumpSidebar(
  WidgetTester tester,
  InMemoryNoteRepository repo,
) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [noteRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const CupertinoApp(
        home: SizedBox(width: 300, child: NoteSidebar()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, container);
}

/// 种子：工作 2 条、生活 1 条；「重要」跨两个文件夹共 2 条，另有一个按
/// 「重要」过滤的智能文件夹。这样重命名/删除必须真的批量改写才瞒不过去。
Future<InMemoryNoteRepository> seededRepo() async {
  final repo = InMemoryNoteRepository();
  await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
  await repo.upsertFolder(const NoteFolder(id: 'f2', name: '生活'));
  await repo.upsertFolder(const NoteFolder(
    id: 'sf1',
    name: '重要事项',
    smart: true,
    filterJson: '{"tagNames":["重要"]}',
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
    folderId: 'f2',
    title: '体检',
    tagNames: ['重要'],
  ));
  return repo;
}

Future<void> openTagActions(WidgetTester tester, String tag) async {
  await tester.tap(find.byKey(ValueKey('note_tag_more_$tag')));
  await tester.pumpAndSettle();
}

Future<void> renameViaSheet(
  WidgetTester tester,
  String tag,
  String next,
) async {
  await openTagActions(tester, tag);
  await tester.tap(find.byKey(ValueKey('note_tag_action_rename_$tag')));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const ValueKey('note_rename_tag_name')), next);
  await tester.tap(find.byKey(const ValueKey('note_rename_tag_ok')));
  await tester.pumpAndSettle();
}

Future<void> deleteViaSheet(WidgetTester tester, String tag) async {
  await openTagActions(tester, tag);
  await tester.tap(find.byKey(ValueKey('note_tag_action_delete_$tag')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('note_delete_tag_ok')));
  await tester.pumpAndSettle();
}

List<String> tagsOf(Note note) => note.tagNames.toList();

Future<Note> noteById(NoteRepository repo, String id) async =>
    (await repo.watchNotes(folderId: null).first).firstWhere((n) => n.id == id);

Future<String?> smartFilter(NoteRepository repo, String id) async =>
    (await repo.watchFolders().first).firstWhere((f) => f.id == id).filterJson;

void main() {
  testWidgets('TC-NOTE-UI-121 标签行有重命名/删除入口，且不摆「新建空标签」死入口',
      (tester) async {
    final (_, _) = await pumpSidebar(tester, await seededRepo());

    expect(find.byKey(const ValueKey('note_tag_more_重要')), findsOneWidget);
    await openTagActions(tester, '重要');
    expect(find.byKey(const ValueKey('note_tag_action_rename_重要')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('note_tag_action_delete_重要')),
        findsOneWidget);

    // Apple 没有「新建空标签」界面：标签是从使用它的备忘录派生的视图，
    // 摆一个点完立刻消失的按钮就是死控件。创建走编辑器内联打标签。
    expect(find.text('新建标签'), findsNothing);
    expect(find.text('创建标签'), findsNothing);
    expect(find.byKey(const ValueKey('note_sidebar_new_tag')), findsNothing);
  });

  testWidgets('TC-NOTE-UI-121 创建面：内联打上新标签后侧栏自然出现该行',
      (tester) async {
    final (repo, _) = await pumpSidebar(tester, await seededRepo());
    expect(find.byKey(const ValueKey('note_sidebar_tag_待办')), findsNothing);

    // 编辑器标签输入（TC-NOTE-UI-106）的落库结果：给 n2 加一个新标签。
    final n2 = await noteById(repo, 'n2');
    await repo.upsertNote(Note(
      id: n2.id,
      folderId: n2.folderId,
      title: n2.title,
      bodyDelta: n2.bodyDelta,
      tagNames: [...n2.tagNames, '待办'],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note_sidebar_tag_待办')), findsOneWidget);
    final badge = tester.widget<Text>(
        find.byKey(const ValueKey('note_tag_count_待办')));
    expect(badge.data, '1');
  });

  testWidgets('TC-NOTE-UI-121 重命名：所有笔记、智能文件夹与选中态一起迁移',
      (tester) async {
    final (repo, container) = await pumpSidebar(tester, await seededRepo());

    // 先选中该标签：改名后高亮必须跟着迁移，否则列表被旧名过滤成空。
    await tester.tap(find.byKey(const ValueKey('note_sidebar_tag_重要')));
    await tester.pumpAndSettle();
    expect(container.read(selectedNoteTagProvider), '重要');

    await renameViaSheet(tester, '重要', '关键');

    expect(find.byKey(const ValueKey('note_sidebar_tag_重要')), findsNothing,
        reason: '旧标签行必须消失');
    expect(find.byKey(const ValueKey('note_sidebar_tag_关键')), findsOneWidget);
    final badge = tester.widget<Text>(
        find.byKey(const ValueKey('note_tag_count_关键')));
    expect(badge.data, '2', reason: '「关键」仍是跨两个文件夹的 2 条笔记');

    final names = (await repo.watchTags().first).map((t) => t.name).toList();
    expect(names, contains('关键'));
    expect(names, isNot(contains('重要')));

    expect(tagsOf(await noteById(repo, 'n1')), ['关键', '今天']);
    expect(tagsOf(await noteById(repo, 'n3')), ['关键']);
    expect(tagsOf(await noteById(repo, 'n2')), ['普通'],
        reason: '无关笔记不该被改写');
    final filter = await smartFilter(repo, 'sf1');
    expect(filter, contains('关键'));
    expect(filter, isNot(contains('重要')));

    expect(container.read(selectedNoteTagProvider), '关键');
  });

  testWidgets('TC-NOTE-UI-121 删除：从所有笔记与智能文件夹移除，选中态清空',
      (tester) async {
    final (repo, container) = await pumpSidebar(tester, await seededRepo());
    await tester.tap(find.byKey(const ValueKey('note_sidebar_tag_重要')));
    await tester.pumpAndSettle();

    await deleteViaSheet(tester, '重要');

    expect(find.byKey(const ValueKey('note_sidebar_tag_重要')), findsNothing);
    // 其它标签仍在，标签分节不该整节消失
    expect(find.byKey(const ValueKey('note_sidebar_section_tags')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('note_sidebar_tag_今天')), findsOneWidget);
    expect(find.byKey(const ValueKey('note_sidebar_tag_普通')), findsOneWidget);

    expect(tagsOf(await noteById(repo, 'n1')), ['今天']);
    expect(tagsOf(await noteById(repo, 'n3')), isEmpty);
    expect(tagsOf(await noteById(repo, 'n2')), ['普通']);
    // 条件里的标签被移除后留空数组：智能文件夹显示为空，而不是悄悄放宽成全部
    expect(await smartFilter(repo, 'sf1'), isNot(contains('重要')));

    expect(container.read(selectedNoteTagProvider), isNull,
        reason: '删掉正选中的标签后应回到「所有备忘录」');
  });

  testWidgets('TC-NOTE-UI-121 重命名到已存在的名字时合并，不产生重复标签',
      (tester) async {
    final (repo, _) = await pumpSidebar(tester, await seededRepo());

    await renameViaSheet(tester, '重要', '普通');

    expect(tagsOf(await noteById(repo, 'n1')), ['普通', '今天']);
    expect(tagsOf(await noteById(repo, 'n2')), ['普通']);
    expect(tagsOf(await noteById(repo, 'n3')), ['普通']);
    final names = (await repo.watchTags().first).map((t) => t.name).toList();
    expect(names, ['今天', '普通'], reason: '两个名字合并成一个，且派生列表无重复');
    expect(find.byKey(const ValueKey('note_sidebar_tag_普通')), findsOneWidget);
  });

  testWidgets('TC-NOTE-UI-121 空名/同名不改写，取消删除不改写', (tester) async {
    final (repo, _) = await pumpSidebar(tester, await seededRepo());

    // 空名：输入框清空后确认
    await openTagActions(tester, '重要');
    await tester.tap(
        find.byKey(const ValueKey('note_tag_action_rename_重要')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('note_rename_tag_name')), '   ');
    await tester.tap(find.byKey(const ValueKey('note_rename_tag_ok')));
    await tester.pumpAndSettle();
    expect(tagsOf(await noteById(repo, 'n1')), ['重要', '今天']);

    // 删除确认框点取消
    await openTagActions(tester, '重要');
    await tester.tap(
        find.byKey(const ValueKey('note_tag_action_delete_重要')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tagsOf(await noteById(repo, 'n1')), ['重要', '今天']);
    expect(find.byKey(const ValueKey('note_sidebar_tag_重要')), findsOneWidget);
  });

  test('TC-NOTE-UI-121 「最近删除」里的笔记也一并改写，恢复后不复活旧标签',
      () async {
    final repo = await seededRepo();
    await repo.upsertNote(const Note(
      id: 'n4',
      folderId: 'f2',
      title: '旧档',
      tagNames: ['重要'],
    ));
    await repo.softDelete('n4');
    final tagsBefore =
        (await repo.watchTags().first).map((t) => t.name).toList();
    expect(tagsBefore, ['今天', '普通', '重要'],
        reason: '软删笔记不该再贡献派生标签');

    await repo.renameTag('重要', '关键');
    await repo.restore('n4');
    final restored = await noteById(repo, 'n4');
    expect(restored.tagNames, ['关键'],
        reason: '只改活笔记的话，恢复时旧标签会复活出一个已不存在的标签行');

    await repo.deleteTag('关键');
    final all = [
      ...await repo.watchNotes(folderId: null).first,
      ...await repo.watchDeleted().first,
    ];
    for (final note in all) {
      expect(note.tagNames, isNot(contains('关键')));
    }
  });
}
