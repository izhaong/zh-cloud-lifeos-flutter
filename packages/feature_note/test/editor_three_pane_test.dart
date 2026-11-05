// #421：宽屏三栏宿主——选中就地编辑，不再推入独立页。
import 'dart:async';

import 'package:feature_note/feature_note.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements NoteRepository {
  _Repo(this.notes);
  List<Note> notes;

  @override
  Stream<List<Note>> watchNotes({String? folderId, String? query}) =>
      Stream.value(notes);

  @override
  Stream<List<NoteFolder>> watchFolders() => Stream.value(const [
        NoteFolder(id: 'f1', name: '笔记', sortOrder: 0),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Note _note(String id, String title) => Note(
      id: id,
      folderId: 'f1',
      title: title,
      bodyText: '正文 $title',
    );

Future<void> _pump(WidgetTester tester, _Repo repo, {double width = 1280}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repo),
        noteSharePortProvider.overrideWithValue(const _NoSharePort()),
      ],
      // 与仓内既有 note 测试同构（菜单命令测试也是裸 CupertinoApp）：
      // 自定义 delegates 反而会把默认的 CupertinoLocalizations 顶掉。
      child: const CupertinoApp(home: NoteScaffold()),
    ),
  );
  await tester.pumpAndSettle();
}

class _NoSharePort implements NoteSharePort {
  const _NoSharePort();

  @override
  bool get isAvailable => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('#421 宽屏：三栏并存，第三栏先是空态', (tester) async {
    final repo = _Repo([_note('n1', '甲'), _note('n2', '乙')]);
    await _pump(tester, repo);

    expect(find.byKey(const Key('note_editor_pane_empty')), findsOneWidget,
        reason: '未选中时第三栏是空态，不是无主语编辑器');
    expect(find.byKey(const Key('note_editor_page')), findsNothing,
        reason: '宽屏不该有推入页的导航栏宿主');
  });

  testWidgets('#421 宽屏：点选一条 → 第三栏就地编辑（无导航栏标题）', (tester) async {
    final repo = _Repo([_note('n1', '甲'), _note('n2', '乙')]);
    await _pump(tester, repo);

    await tester.tap(find.text('甲').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_editor_embedded')), findsOneWidget);
    expect(find.text('编辑备忘录'), findsNothing,
        reason: '内嵌宿主不该出现「编辑备忘录」导航栏标题');
    expect(find.text('甲'), findsWidgets);
  });

  testWidgets('#421 窄屏仍是推入页（不破坏手机形态）', (tester) async {
    final repo = _Repo([_note('n1', '甲')]);
    await _pump(tester, repo, width: 400);

    expect(find.byKey(const Key('note_editor_pane_empty')), findsNothing,
        reason: '窄屏没有第三栏');

    await tester.tap(find.text('甲').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_editor_page')), findsOneWidget,
        reason: '窄屏保留推入页 + 导航栏');
  });

  testWidgets('#421 切换记录会重建编辑器（不残留上一条内容）', (tester) async {
    final repo = _Repo([_note('n1', '甲'), _note('n2', '乙')]);
    await _pump(tester, repo);

    await tester.tap(find.text('甲').first);
    await tester.pumpAndSettle();
    final firstKey = find.byKey(const ValueKey('note_editor_pane_n1'));
    expect(firstKey, findsOneWidget);

    await tester.tap(find.text('乙').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note_editor_pane_n2')), findsOneWidget);
    expect(find.byKey(const ValueKey('note_editor_pane_n1')), findsNothing);
  });
}
