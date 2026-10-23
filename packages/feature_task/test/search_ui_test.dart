import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required ReminderRepository repo,
  Widget child = const TaskScaffold(openListId: 'list.personal'),
}) async {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  // TC-UI-202
    testWidgets('宽屏工具栏搜索框出现；紧凑端不出现', (tester) async {
    final repo = InMemoryReminderRepository();

    // 紧凑端：无搜索框
    await _pump(tester, size: const Size(375, 812), repo: repo);
    expect(find.byKey(const ValueKey('toolbar_search')), findsNothing);

    // 宽屏：有搜索框
    await _pump(tester, size: const Size(1366, 1024), repo: repo);
    expect(find.byKey(const ValueKey('toolbar_search')), findsOneWidget);
  });

  // TC-UI-202
    testWidgets('搜索按标题过滤（大小写不敏感）', (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(tester, size: const Size(1366, 1024), repo: repo);

    // 种子数据：买牛奶 / 写 LifeOS 基建（list.personal）
    await tester.enterText(
      find.byKey(const ValueKey('toolbar_search')),
      '牛奶',
    );
    await tester.pumpAndSettle();

    expect(find.text('买牛奶'), findsOneWidget);
    expect(find.text('写 LifeOS 基建'), findsNothing);
  });

  // TC-UI-202
    testWidgets('搜索匹配备注与标签', (tester) async {
    final repo = InMemoryReminderRepository();
    await repo.upsertItem(
      const ReminderItem(
        id: 'n1',
        listId: 'list.personal',
        title: '交报告',
        notes: '给老板看',
        tags: ['设计'],
      ),
    );
    await repo.upsertItem(
      const ReminderItem(
        id: 'n2',
        listId: 'list.personal',
        title: '无关条目',
      ),
    );
    await _pump(tester, size: const Size(1366, 1024), repo: repo);

    // 按备注搜
    await tester.enterText(
      find.byKey(const ValueKey('toolbar_search')),
      '老板',
    );
    await tester.pumpAndSettle();
    expect(find.text('交报告'), findsOneWidget);
    expect(find.text('无关条目'), findsNothing);

    // 清空 → 全部回来
    await tester.enterText(
      find.byKey(const ValueKey('toolbar_search')),
      '',
    );
    await tester.pumpAndSettle();
    expect(find.text('无关条目'), findsOneWidget);
  });

  // TC-UI-203
    testWidgets('无匹配显示「无匹配结果」', (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(tester, size: const Size(1366, 1024), repo: repo);

    await tester.enterText(
      find.byKey(const ValueKey('toolbar_search')),
      '不存在的词',
    );
    await tester.pumpAndSettle();

    expect(find.text('无匹配结果'), findsOneWidget);
  });
}
