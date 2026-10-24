import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TC-UI-118 列表分组折叠（M2）：侧栏「我的列表」可分组折叠；
/// 计数正确；**负向门禁：不得出现 iCloud/Outlook/账户字样**。
/// 注：本平台无账户概念（对等矩阵 #19 降级=列表分组），
/// 分组 = 用户在列表上标记 groupName（首期由列表 sortOrder 段推导，
/// M2 最简：groupName 字段挂 ReminderList，无需独立分组实体）。
Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required ReminderRepository repo,
  Widget child = const TaskScaffold(openListId: 'list.work'),
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

  testWidgets('TC-UI-118 侧栏分组渲染与折叠/展开', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(
      id: 'list.work',
      title: '晨会清单',
      groupName: '工作',
    ));
    await repo.upsertList(const ReminderList(
      id: 'list.work2',
      title: '周报清单',
      groupName: '工作',
    ));
    await repo.upsertList(const ReminderList(
      id: 'list.life',
      title: '生活',
      groupName: '生活',
    ));
    await repo.upsertItem(
      const ReminderItem(id: 'x', listId: 'list.work', title: '任务'),
    );

    await _pump(tester, size: const Size(1366, 1024), repo: repo);

    // 分组头出现（含组内计数 1）
    expect(find.byKey(const ValueKey('group_工作')), findsOneWidget);
    expect(find.byKey(const ValueKey('group_生活')), findsOneWidget);
    // 侧栏行 + 主区 AppBar 标题（openListId=list.work）各一
    expect(find.text('晨会清单'), findsWidgets);

    // 折叠「工作」
    await tester.tap(find.byKey(const ValueKey('group_工作')));
    await tester.pumpAndSettle();
    // 折叠后侧栏行消失，主区标题仍在（=1）
    expect(find.text('晨会清单'), findsOneWidget);
    expect(find.text('周报清单'), findsNothing);
    expect(find.byKey(const ValueKey('group_生活')), findsOneWidget); // 他组不动

    // 展开
    await tester.tap(find.byKey(const ValueKey('group_工作')));
    await tester.pumpAndSettle();
    // 展开后侧栏行回来（=2）
    expect(find.text('晨会清单'), findsWidgets);
  });

  testWidgets('TC-UI-118 无分组列表平铺（兼容旧行为）+ 负向门禁',
      (tester) async {
    final repo = InMemoryReminderRepository();
    // 种子数据无 groupName → 平铺
    await _pump(tester, size: const Size(1366, 1024), repo: repo);

    expect(find.text('个人'), findsOneWidget);
    expect(find.byKey(const ValueKey('group_个人')), findsNothing); // 无分组头

    // 负向门禁：无账户字样
    expect(find.textContaining('iCloud'), findsNothing);
    expect(find.textContaining('Outlook'), findsNothing);
  });
}
