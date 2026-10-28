import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// #256 / 任务矩阵 row 11：Apple 的「显示已完成」是**列表内开关**（每列表一份），
/// 切列表不串味、重开仍在。此前只有全局一个布尔，切换列表就串。
void main() {
  Future<InMemoryReminderRepository> seed() async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '列表A'));
    await repo.upsertList(const ReminderList(id: 'list.b', title: '列表B'));
    await repo.upsertItem(ReminderItem(
      id: 'a-done',
      listId: 'list.a',
      title: 'A 已完成',
      isCompleted: true,
      completedAt: DateTime(2026, 10, 24),
    ));
    await repo.upsertItem(ReminderItem(
      id: 'b-done',
      listId: 'list.b',
      title: 'B 已完成',
      isCompleted: true,
      completedAt: DateTime(2026, 10, 24),
    ));
    return repo;
  }

  Future<void> pumpList(
    WidgetTester tester,
    ProviderContainer container,
    String listId,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: TaskScaffold(openListId: listId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('在列表 A 打开「显示已完成」后切到列表 B 不串（B 仍隐藏）', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final repo = await seed();
    final container = ProviderContainer(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        taskViewPrefsProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await pumpList(tester, container, 'list.a');
    expect(find.text('A 已完成'), findsNothing, reason: '默认隐藏已完成');

    await tester.tap(find.byKey(const ValueKey('toggle_show_completed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示已完成').last);
    await tester.pumpAndSettle();
    expect(find.text('A 已完成'), findsOneWidget);
    expect(container.read(showCompletedByListProvider)['list.a'], isTrue);

    // 切到列表 B：同一容器，B 没有自己的记录 → 隐藏
    await pumpList(tester, container, 'list.b');
    expect(
      find.text('B 已完成'),
      findsNothing,
      reason: 'A 的开关不得影响 B（Apple：列表内开关）',
    );
    expect(container.read(showCompletedByListProvider)['list.b'], isNull);
  });

  testWidgets('重开应用仍记得每个列表的选择', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final repo = await seed();

    final first = ProviderContainer(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        taskViewPrefsProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(first.dispose);
    first.read(showCompletedByListProvider.notifier).setFor('list.a', true);
    await prefs.reload();

    final second = ProviderContainer(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        taskViewPrefsProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(second.dispose);
    expect(
      second.read(showCompletedByListProvider)['list.a'],
      isTrue,
      reason: '本地 prefs 要读回按列表的记忆',
    );
  });

  testWidgets('未注入 prefs 时不崩，全局偏好仍写「最后一次」', (tester) async {
    final container = ProviderContainer(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(await seed()),
      ],
    );
    addTearDown(container.dispose);
    container.read(showCompletedByListProvider.notifier).setFor('list.a', true);
    expect(container.read(showCompletedByListProvider)['list.a'], isTrue);
    expect(container.read(showCompletedProvider), isTrue,
        reason: '全局那一格仍写「最后一次」（服务端同步契约不变）');
  });
}
