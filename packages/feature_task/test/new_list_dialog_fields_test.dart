import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TC-UI-115/316：新建列表对话框图4 全字段（名称/颜色/图标/类型）；
/// TC-UI-313：类型下拉（标准/日常采购）；grocery 预置 8 分区。
Future<void> _pump(
  WidgetTester tester, {
  required ReminderRepository repo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const ValueKey('open_dialog'),
                onPressed: () => showNewListDialog(
                  context,
                  onCreate: (list) => repo.upsertList(list),
                ),
                child: const Text('新建'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('TC-UI-115 四字段齐备：名称/颜色/图标/类型；空名禁提交',
      (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await _pump(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('open_dialog')));
    await tester.pumpAndSettle();

    // 图4 四字段齐备
    expect(find.byType(TextField), findsOneWidget); // 名称
    expect(find.byKey(const ValueKey('color_4281648985')), findsOneWidget);
    expect(find.byKey(const ValueKey('icon_cart')), findsOneWidget);
    expect(find.byKey(const ValueKey('list_type')), findsOneWidget);

    // 空名禁提交
    await tester.tap(find.byKey(const ValueKey('new_list_submit')));
    await tester.pumpAndSettle();
    final lists = await repo.watchLists().first;
    expect(
      lists.where((e) => !e.isSmart),
      isEmpty,
      reason: '空名称不得创建列表',
    );
  });

  testWidgets('TC-UI-313 类型=日常采购 → 预置 8 分区模板', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await _pump(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('open_dialog')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '周采购');
    // 选采购类型
    await tester.tap(find.byKey(const ValueKey('list_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日常采购（预置分区）').last);
    await tester.pumpAndSettle();

    // 选购物车图标
    await tester.tap(find.byKey(const ValueKey('icon_cart')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('new_list_submit')));
    await tester.pumpAndSettle();

    final lists = await repo.watchLists().first;
    final created = lists.firstWhere((e) => e.title == '周采购');
    expect(created.listType, ReminderListType.grocery);
    expect(created.sections.length, 8);
    expect(created.sections.first.title, '农产品');
    expect(created.sections.last.title, '日用品');
  });

  testWidgets('TC-UI-313 类型=标准 → 无预置分区', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await _pump(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('open_dialog')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '普通清单');
    await tester.tap(find.byKey(const ValueKey('new_list_submit')));
    await tester.pumpAndSettle();

    final lists = await repo.watchLists().first;
    final created = lists.firstWhere((e) => e.title == '普通清单');
    expect(created.listType, ReminderListType.standard);
    expect(created.sections, isEmpty);
  });
}
