import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'support/life_test_app.dart';

/// TC-KR-105（子任务平铺契约）客户端半边收口：
/// `task_scaffold.dart` 的顶层兜底分支（行 1086「孤儿（父不在结果集）或自环
/// → 按顶层渲染」）此前只有注释、无种子用例。本文件补两类种子：
///  1) 孤儿（parentId 指向不存在的条目）按顶层渲染、不被丢弃；
///  2) 自环（parentId == 自身 id）按顶层渲染、不无限递归、不重复渲染。
void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<InMemoryReminderRepository> _seed() async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '列表A'));
    await repo.upsertItem(
      const ReminderItem(id: 'p', listId: 'list.a', title: '父'),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'c', listId: 'list.a', title: '子', parentId: 'p'),
    );
    // 孤儿：父不在结果集
    await repo.upsertItem(
      const ReminderItem(id: 'o', listId: 'list.a', title: '孤儿', parentId: 'ghost'),
    );
    // 自环：parentId == 自身
    await repo.upsertItem(
      const ReminderItem(id: 's', listId: 'list.a', title: '自环', parentId: 's'),
    );
    return repo;
  }

  Future<void> _pump(WidgetTester tester, ReminderRepository repo) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: TaskScaffold(openListId: 'list.a')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('TC-KR-105 孤儿与自环按顶层渲染（不丢、不环）', (tester) async {
    final repo = await _seed();
    await _pump(tester, repo);

    // 全部四条均渲染：父/子/孤儿/自环
    expect(find.text('父'), findsOneWidget);
    expect(find.text('子'), findsOneWidget, reason: '子任务正常嵌套渲染');
    expect(find.text('孤儿'), findsOneWidget, reason: '孤儿按顶层渲染、不被丢弃');
    expect(find.text('自环'), findsOneWidget, reason: '自环按顶层渲染、不无限递归');

    // 数据层：watchItems 仍返回全层级（孤儿/自环未被清理）
    final all = await repo.watchItems().first;
    expect(all.map((e) => e.id), containsAll(<String>['p', 'c', 'o', 's']));

    // 孤儿/自环的 parentId 原样保留（未被改写）
    final o = all.firstWhere((e) => e.id == 'o');
    final s = all.firstWhere((e) => e.id == 's');
    expect(o.parentId, 'ghost');
    expect(s.parentId, 's');
  });

  testWidgets('TC-KR-105 仅有自环单条目：渲染恰好一次', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '列表A'));
    await repo.upsertItem(
      const ReminderItem(id: 'solo', listId: 'list.a', title: '自环', parentId: 'solo'),
    );
    await _pump(tester, repo);

    // 不无限递归 → 恰好一个「自环」文本（若递归会渲染多份或卡死）
    expect(find.text('自环'), findsOneWidget);
  });
}
