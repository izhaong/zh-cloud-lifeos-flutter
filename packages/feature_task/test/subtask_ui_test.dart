import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required ReminderRepository repo,
  Widget child = const TaskScaffold(
    openListId: 'list.personal',
    selectedItemId: '1',
  ),
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

  testWidgets('详情面板：添加子任务 → 列表行呈现缩进子任务', (tester) async {
    final repo = InMemoryReminderRepository();
    await _pump(tester, size: const Size(1366, 1024), repo: repo);

    // 详情第三栏内添加子任务
    await tester.tap(find.text('添加子任务'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '子任务'), '准备购物清单');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // 中栏列表出现缩进子任务行
    expect(find.text('准备购物清单'), findsWidgets);

    // 仓库里子任务挂在父条目下
    final items = await repo.watchItems(listId: 'list.personal').first;
    final sub = items.firstWhere((e) => e.title == '准备购物清单');
    expect(sub.parentId, '1');
    expect(sub.isSubtask, isTrue);
  });

  testWidgets('详情面板：勾选子任务即时完成', (tester) async {
    final repo = InMemoryReminderRepository();
    // 预置一条子任务
    await repo.upsertItem(
      const ReminderItem(
        id: 'sub1',
        listId: 'list.personal',
        title: '买牛奶的子任务',
        parentId: '1',
      ),
    );
    await _pump(tester, size: const Size(1366, 1024), repo: repo);

    // 第三栏子任务区显示该子任务
    expect(find.text('买牛奶的子任务'), findsWidgets);

    // 勾选（详情子任务区的完成圆圈）
    final circles = find.byIcon(_circleIcon);
    await tester.tap(circles.last);
    await tester.pumpAndSettle();

    final items = await repo.watchItems(listId: 'list.personal').first;
    final sub = items.firstWhere((e) => e.id == 'sub1');
    expect(sub.isCompleted, isTrue);
  });

  testWidgets('详情面板：滑删子任务级联不伤父条目', (tester) async {
    final repo = InMemoryReminderRepository();
    await repo.upsertItem(
      const ReminderItem(
        id: 'sub1',
        listId: 'list.personal',
        title: '待删子任务',
        parentId: '1',
      ),
    );
    await _pump(tester, size: const Size(1366, 1024), repo: repo);

    await tester.drag(
      find.text('待删子任务').last,
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();

    final items = await repo.watchItems(listId: 'list.personal').first;
    expect(items.where((e) => e.id == 'sub1'), isEmpty);
    expect(items.where((e) => e.id == '1'), isNotEmpty); // 父条目仍在
  });
}

// CupertinoIcons.circle 的 IconData 常量在 material 命名空间外，直接引用：
const _circleIcon = IconData(0xF401,
    fontFamily: 'CupertinoIcons', fontPackage: 'cupertino_icons');
