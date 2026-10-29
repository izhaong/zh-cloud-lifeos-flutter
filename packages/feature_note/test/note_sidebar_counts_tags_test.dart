import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// parity#393：备忘录侧栏缺的两件——数量徽章与分节（「文件夹」/「标签」）。
///
/// 判据只看仓库真值算出来的东西：徽章数字必须等于该文件夹（标签）下未删除笔记
/// 的条数，点标签必须真的过滤 [visibleNotesProvider]，且与文件夹选中互斥
/// （用「跨文件夹的笔记出现在列表里」来证文件夹过滤确实被清掉）。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// 种子：工作 2 条（周报=重要+今天、买菜=普通）、生活 1 条（体检=重要）、
  /// 空文件夹 1 个。这样徽章要区分 2 / 1 / 0，标签要跨文件夹。
  Future<InMemoryNoteRepository> seededRepo() async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertFolder(const NoteFolder(id: 'f2', name: '生活'));
    await repo.upsertFolder(const NoteFolder(id: 'f3', name: '归档'));
    Future<void> seed(Note note) => repo.upsertNote(note);
    await seed(
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: '周报',
        bodyDelta: '{"ops":[{"insert":"周报正文"}]}',
        tagNames: ['重要', '今天'],
      ),
    );
    await seed(
      const Note(
        id: 'n2',
        folderId: 'f1',
        title: '买菜',
        bodyDelta: '{"ops":[{"insert":"豆腐和鸡蛋"}]}',
        tagNames: ['普通'],
      ),
    );
    await seed(
      const Note(
        id: 'n3',
        folderId: 'f2',
        title: '体检',
        bodyDelta: '{"ops":[{"insert":"挂号流程"}]}',
        tagNames: ['重要'],
      ),
    );
    return repo;
  }

  Future<void> pumpWide(
    WidgetTester tester,
    InMemoryNoteRepository repo,
  ) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String badgeText(WidgetTester tester, String key) {
    final widget = tester.widget<Text>(find.byKey(ValueKey(key)));
    return widget.data ?? '';
  }

  testWidgets('分节标题与每行数量徽章按仓库真值给出（含 0）', (tester) async {
    final repo = await seededRepo();
    await pumpWide(tester, repo);

    expect(find.byKey(const ValueKey('note_sidebar_section_folders')),
        findsOneWidget);
    expect(find.text('文件夹'), findsOneWidget);

    // 徽章 = 未删除笔记计数；空文件夹也给 0（不给数字就分不清「空」和「没算」）
    expect(badgeText(tester, 'note_folder_count_all'), '3');
    expect(badgeText(tester, 'note_folder_count_f1'), '2');
    expect(badgeText(tester, 'note_folder_count_f2'), '1');
    expect(badgeText(tester, 'note_folder_count_f3'), '0');

    // 标签节：名字来自存活笔记的 tagNames，徽章 = 打了该标签的笔记数
    expect(find.byKey(const ValueKey('note_sidebar_section_tags')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('note_sidebar_tag_重要')), findsOneWidget);
    expect(badgeText(tester, 'note_tag_count_重要'), '2');
    expect(badgeText(tester, 'note_tag_count_今天'), '1');
  });

  testWidgets('删掉的笔记不再计入徽章', (tester) async {
    final repo = await seededRepo();
    await pumpWide(tester, repo);
    expect(badgeText(tester, 'note_folder_count_f1'), '2');

    await repo.softDelete('n2');
    await tester.pumpAndSettle();

    expect(badgeText(tester, 'note_folder_count_f1'), '1');
    expect(badgeText(tester, 'note_folder_count_all'), '2');
    // 「普通」只挂在被删那条上：标签是从存活笔记派生的，行本身就该消失
    expect(find.byKey(const ValueKey('note_tag_count_普通')), findsNothing);
    expect(find.byKey(const ValueKey('note_sidebar_tag_普通')), findsNothing);
  });

  testWidgets('点标签 = 跨文件夹按标签浏览；再点同标签取消', (tester) async {
    final repo = await seededRepo();
    await pumpWide(tester, repo);

    // 默认全部：三条都在
    expect(find.text('周报'), findsOneWidget);
    expect(find.text('买菜'), findsOneWidget);
    expect(find.text('体检'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note_sidebar_tag_重要')));
    await tester.pumpAndSettle();

    // 「重要」= 周报(f1) + 体检(f2)，不含 买菜
    expect(find.text('周报'), findsOneWidget);
    expect(find.text('体检'), findsOneWidget);
    expect(find.text('买菜'), findsNothing);

    // 再点同一个标签 = 取消过滤
    await tester.tap(find.byKey(const ValueKey('note_sidebar_tag_重要')));
    await tester.pumpAndSettle();
    expect(find.text('买菜'), findsOneWidget);
    expect(find.text('体检'), findsOneWidget);
  });

  testWidgets('先选文件夹再点标签：文件夹过滤被清掉（两把高亮不并存）',
      (tester) async {
    final repo = await seededRepo();
    await pumpWide(tester, repo);

    await tester.tap(find.byKey(const ValueKey('note_sidebar_f1')));
    await tester.pumpAndSettle();
    expect(find.text('周报'), findsOneWidget);
    expect(find.text('体检'), findsNothing); // 生活文件夹的此时不可见

    await tester.tap(find.byKey(const ValueKey('note_sidebar_tag_重要')));
    await tester.pumpAndSettle();

    // 若文件夹选中没被清掉，这里只会剩「周报」；出现「体检」即证明过滤切回标签侧
    expect(find.text('体检'), findsOneWidget);
    expect(find.text('周报'), findsOneWidget);
    expect(find.text('买菜'), findsNothing);

    // 反向：点文件夹也要清掉标签
    await tester.tap(find.byKey(const ValueKey('note_sidebar_f2')));
    await tester.pumpAndSettle();
    expect(find.text('体检'), findsOneWidget);
    expect(find.text('周报'), findsNothing);
  });

  testWidgets('没有标签时不摆空分节', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await pumpWide(tester, repo);

    expect(find.byKey(const ValueKey('note_sidebar_section_folders')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('note_sidebar_section_tags')), findsNothing);
    expect(find.text('标签'), findsNothing);
    expect(badgeText(tester, 'note_folder_count_f1'), '0');
  });
}
