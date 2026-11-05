import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #2 · M2 第三批：最近删除（TC-UI-109）与标签浏览器（TC-UI-117）。
void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<InMemoryReminderRepository> seed() async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
        const ReminderList(id: 'list.a', title: '列表A'));
    await repo.upsertItem(const ReminderItem(
        id: 'i1', listId: 'list.a', title: '买牛奶', tags: ['购物']));
    await repo.upsertItem(const ReminderItem(
        id: 'i2', listId: 'list.a', title: '写周报', tags: ['工作']));
    return repo;
  }

  Future<void> pumpApp(WidgetTester tester, ReminderRepository repo,
      {String? openListId}) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1366, 1024)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: TaskScaffold(openListId: openListId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('TC-UI-109 删除 → 最近删除视图可见 → 恢复回原列表', (tester) async {
    final repo = await seed();
    await pumpApp(tester, repo, openListId: 'list.a');

    // 删除 i1（左滑删除未做 UI，走仓库；UI 断言回收窗与恢复）
    await repo.deleteItem('i1');
    await tester.pumpAndSettle();
    expect(find.text('买牛奶'), findsNothing); // 列表内消失

    // 侧栏「最近删除」选中态由宿主驱动（三栏 onOpenList 回调），测试直接换视图
    expect(find.text('最近删除'), findsOneWidget); // 侧栏入口在
    await pumpApp(tester, repo, openListId: 'smart.trash');
    expect(find.text('买牛奶'), findsOneWidget);
    expect(find.text('新提醒'), findsNothing); // trash 无新建入口

    // 恢复
    await tester.tap(find.byKey(const ValueKey('restore_i1')));
    await tester.pumpAndSettle();
    expect(find.text('买牛奶'), findsNothing); // 离开回收窗

    final back = await repo.watchItems(listId: 'list.a').first;
    expect(back.map((e) => e.id), contains('i1'));
  });

  testWidgets('TC-UI-109 宽屏回收站空态：有标题与保留期说明，不再是整页空白（#163）',
      (tester) async {
    final repo = await seed();
    await pumpApp(tester, repo, openListId: 'smart.trash');

    expect(find.byKey(const ValueKey('trash_header')), findsOneWidget);
    expect(find.text('项目将在删除 30 天后永久移除'), findsOneWidget);
    expect(find.byKey(const ValueKey('trash_empty')), findsOneWidget);
    expect(find.text('没有最近删除的提醒事项'), findsOneWidget);
  });

  testWidgets('TC-UI-109 宽屏回收站有条目：标题在场且行尾可恢复（#163）',
      (tester) async {
    final repo = await seed();
    await repo.deleteItem('i1');
    await pumpApp(tester, repo, openListId: 'smart.trash');

    expect(find.byKey(const ValueKey('trash_header')), findsOneWidget);
    expect(find.byKey(const ValueKey('trash_empty')), findsNothing);
    expect(find.text('买牛奶'), findsOneWidget);
    expect(find.byKey(const ValueKey('restore_i1')), findsOneWidget);
  });

  testWidgets('TC-UI-117 标签浏览器：chip 出现，点选即按标签过滤', (tester) async {
    final repo = await seed();
    await pumpApp(tester, repo, openListId: 'list.a');

    expect(find.byKey(const ValueKey('tag_chip_购物')), findsOneWidget);
    expect(find.byKey(const ValueKey('tag_chip_工作')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tag_chip_工作')));
    await tester.pumpAndSettle();

    expect(find.text('写周报'), findsOneWidget); // 命中
    expect(find.text('买牛奶'), findsNothing); // 过滤掉
  });
}
