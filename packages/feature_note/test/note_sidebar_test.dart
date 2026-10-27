import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-101：文件夹侧栏（F-04）。
/// 造两个文件夹，点其中一个 → 主区只显示该文件夹的笔记。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<InMemoryNoteRepository> seededRepo() async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertFolder(const NoteFolder(id: 'f2', name: '生活'));
    await repo.upsertNote(const Note(
      id: 'n1',
      folderId: 'f1',
      title: '周报',
      bodyDelta: '{"ops":[{"insert":"周报正文"}]}',
    ));
    await repo.upsertNote(const Note(
      id: 'n2',
      folderId: 'f2',
      title: '购物',
      bodyDelta: '{"ops":[{"insert":"买菜"}]}',
    ));
    return repo;
  }

  Future<void> pumpWide(WidgetTester tester, InMemoryNoteRepository repo) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: NoteScaffold()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('侧栏列出文件夹；点选后主区只显示该文件夹的笔记',
      (tester) async {
    final repo = await seededRepo();
    await pumpWide(tester, repo);

    // 侧栏：所有备忘录 + 两个文件夹
    expect(find.text('所有备忘录'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('生活'), findsOneWidget);
    // 默认全部：两条笔记都在
    expect(find.text('周报'), findsOneWidget);
    expect(find.text('购物'), findsOneWidget);

    // 点「工作」→ 只剩工作文件夹的笔记
    await tester.tap(find.byKey(const ValueKey('note_sidebar_f1')));
    await tester.pumpAndSettle();
    expect(find.text('周报'), findsOneWidget);
    expect(find.text('购物'), findsNothing);

    // 点「所有备忘录」→ 恢复全部
    await tester.tap(find.byKey(const ValueKey('note_sidebar_all')));
    await tester.pumpAndSettle();
    expect(find.text('周报'), findsOneWidget);
    expect(find.text('购物'), findsOneWidget);
  });

  testWidgets('窄屏用抽屉承载侧栏', (tester) async {
    final repo = await seededRepo();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(375, 812)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: NoteScaffold()),
      ),
    );
    await tester.pumpAndSettle();

    // 侧栏不常显；打开抽屉后可见文件夹
    expect(find.text('所有备忘录'), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('所有备忘录'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
  });
}
