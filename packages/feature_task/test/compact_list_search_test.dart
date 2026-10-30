// #485 / 矩阵行 15（搜索）/ TC-UI-105：
// 紧凑档（<600）进入任一列表后必须有搜索入口；此前只有紧凑首页有 home_search。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

Future<InMemoryReminderRepository> _seed() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.p', title: '工作'));
  final today = DateTime.now();
  final day = DateTime(today.year, today.month, today.day);
  await repo.upsertItem(
    ReminderItem(
      id: 'call',
      listId: 'list.p',
      title: '打电话给设计师',
      dueAt: day.add(const Duration(hours: 10)),
    ),
  );
  await repo.upsertItem(
    ReminderItem(
      id: 'report',
      listId: 'list.p',
      title: '写季度报告',
      dueAt: day.add(const Duration(hours: 11)),
    ),
  );
  return repo;
}

void main() {
  testWidgets('紧凑列表视图有搜索入口并能过滤（#485）', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(420, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final repo = await _seed();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(const TaskScaffold(openListId: 'smart.today')),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('compact_search'));
    expect(search, findsOneWidget, reason: '紧凑列表视图必须有搜索字段');
    expect(
      find.byKey(const ValueKey('toolbar_search')),
      findsNothing,
      reason: '紧凑档不出现宽屏工具栏搜索框',
    );
    expect(find.text('打电话给设计师'), findsOneWidget);
    expect(find.text('写季度报告'), findsOneWidget);

    await tester.enterText(search, '电话');
    await tester.pumpAndSettle();
    expect(find.text('打电话给设计师'), findsOneWidget);
    expect(find.text('写季度报告'), findsNothing);

    await tester.enterText(search, '不存在');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search_empty')), findsOneWidget);
  });
}
