import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  Widget child = const TaskScaffold(),
}) async {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(
          InMemoryReminderRepository(),
        ),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  // TC-UI-204/205
    testWidgets('紧凑单栏：智能列表卡片 + 我的列表 + 计数', (tester) async {
    await _pump(tester, size: const Size(375, 812));

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('计划'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('已旗标'), findsOneWidget);
    expect(find.text('我的列表'), findsOneWidget);
    expect(find.text('个人'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
  });

  // TC-UI-204
    testWidgets('紧凑单栏：点开列表 → 走 onOpenList 回调（壳层路由）', (tester) async {
    final opened = <String>[];
    await _pump(
      tester,
      size: const Size(375, 812),
      child: TaskScaffold(onOpenList: (id) => opened.add(id)),
    );

    await tester.tap(find.text('个人'));
    await tester.pumpAndSettle();
    expect(opened, contains('list.personal'));
  });

  // TC-UI-302/303
    testWidgets('中等二栏：侧栏 + 当前列表内容', (tester) async {
    await _pump(
      tester,
      size: const Size(834, 1112),
      child: const TaskScaffold(openListId: 'list.personal'),
    );

    // 侧栏与内容同时可见
    expect(find.text('智能列表'), findsOneWidget);
    expect(find.text('我的列表'), findsOneWidget);
    expect(find.text('买牛奶'), findsOneWidget);
  });

  // TC-UI-307
    testWidgets('展开三栏：详情选中时出现第三列', (tester) async {
    await _pump(
      tester,
      size: const Size(1366, 1024),
      child: const TaskScaffold(
        openListId: 'list.personal',
        selectedItemId: '1',
      ),
    );

    expect(find.text('详细信息'), findsOneWidget);
  });

  // TC-UI-307
    testWidgets('展开三栏：未选详情时无第三列', (tester) async {
    await _pump(
      tester,
      size: const Size(1366, 1024),
      child: const TaskScaffold(openListId: 'list.personal'),
    );

    expect(find.text('详细信息'), findsNothing);
  });

  // TC-UI-209
    testWidgets('完成圆圈点击后行内容自动更新（无手动 reload）', (tester) async {
    await _pump(
      tester,
      size: const Size(834, 1112),
      child: const TaskScaffold(openListId: 'list.personal'),
    );

    final circles = find.byIcon(CupertinoIcons.circle);
    expect(circles, findsNWidgets(2));
    await tester.tap(circles.first);
    await tester.pumpAndSettle();

    // 完成后行划线；流广播自动刷新（无手动 reload）
    expect(find.byIcon(CupertinoIcons.check_mark_circled_solid), findsOneWidget);
  });
}
