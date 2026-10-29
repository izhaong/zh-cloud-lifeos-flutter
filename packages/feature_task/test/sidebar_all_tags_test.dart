import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #417：侧栏标签区缺「所有标签」总入口（Apple 提醒事项同区首行）。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<InMemoryReminderRepository> seed({required bool withTags}) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '列表A'));
    await repo.upsertItem(
      ReminderItem(
        id: 'i1',
        listId: 'list.a',
        title: '买牛奶',
        tags: withTags ? const ['购物'] : const [],
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'i2',
        listId: 'list.a',
        title: '写周报',
        tags: withTags ? const ['工作'] : const [],
      ),
    );
    return repo;
  }

  Future<void> pumpApp(
    WidgetTester tester,
    ReminderRepository repo,
  ) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1366, 1024)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TaskScaffold(openListId: 'list.a')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('标签区首行是「所有标签」，且排在 chip 之前', (tester) async {
    final repo = await seed(withTags: true);
    await pumpApp(tester, repo);

    expect(find.byKey(const ValueKey('sidebar_all_tags')), findsOneWidget);
    expect(find.text('所有标签'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('sidebar_all_tags'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('tag_chip_工作'))).dy,
      ),
    );
  });

  testWidgets('点「所有标签」清除标签筛选（不是无行为的占位文本）', (tester) async {
    final repo = await seed(withTags: true);
    await pumpApp(tester, repo);

    await tester.tap(find.byKey(const ValueKey('tag_chip_工作')));
    await tester.pumpAndSettle();
    expect(find.text('写周报'), findsOneWidget);
    expect(find.text('买牛奶'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sidebar_all_tags')));
    await tester.pumpAndSettle();
    expect(find.text('写周报'), findsOneWidget);
    expect(find.text('买牛奶'), findsOneWidget);
  });

  testWidgets('没有任何标签时不摆总入口（与标签分节同进同出）', (tester) async {
    final repo = await seed(withTags: false);
    await pumpApp(tester, repo);

    expect(find.byKey(const ValueKey('sidebar_all_tags')), findsNothing);
    expect(find.text('所有标签'), findsNothing);
    // 反向对照：同一份夹具换成带标签的数据，两条判据都必须数得到。
    final tagged = await seed(withTags: true);
    await pumpApp(tester, tagged);
    expect(find.byKey(const ValueKey('sidebar_all_tags')), findsOneWidget);
    expect(find.text('所有标签'), findsOneWidget);
  });
}
