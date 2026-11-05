// TC-NOTE-UI-101 补强（#375）：菜单「文件 → 新建备忘录」必须有接收方。
//
// #368 只把菜单栏做出来：两项新建通过 `ValueNotifier<LifeMenuAction?>` 发命令，
// 但**没有任何页面订阅**——点了没反应，比默认英文菜单更糟（给了入口却不响应）。
import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('#375 菜单命令 newNote → 记录页新建一条并进入编辑', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '备忘录'));
    final commands = ValueNotifier<LifeMenuAction?>(null);
    addTearDown(commands.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          lifeMenuCommandsProvider.overrideWithValue(commands),
        ],
        child: const CupertinoApp(home: NoteScaffold()),
      ),
    );
    await tester.pumpAndSettle();

    // 模拟菜单栏点「新建备忘录」
    commands.value = LifeMenuAction.newNote;
    await tester.pumpAndSettle();

    expect(find.byType(NoteEditorPage), findsOneWidget,
        reason: '应进入编辑器（与导航栏「＋」同一路径），而不是原地无反应；'
            '注意新建的笔记在**保存时**才落库，这里不断言仓库条数');
    expect(commands.value, isNull,
        reason: '命令消费后必须清空，否则下次重建会重复触发');
  });
}
