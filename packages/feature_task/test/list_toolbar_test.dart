import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #2 · M2 第二批：列表头工具行（线框图2）
/// TC-UI-108 显示已完成开关；TC-UI-111 列表内排序；
/// 清除已完成（图2「N 项完成 · 清除」）；TC-UI-119 移动提醒到其他列表（清分区）。
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
    await repo.upsertList(
        const ReminderList(id: 'list.b', title: '列表B'));
    await repo.upsertItem(const ReminderItem(
        id: 'open1', listId: 'list.a', title: '香蕉'));
    await repo.upsertItem(const ReminderItem(
        id: 'open2', listId: 'list.a', title: '苹果'));
    // 完成一条（走仓库以联动 completedAt）
    await repo.toggleCompleted('open2');
    return repo;
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    required ReminderRepository repo,
    Size size = const Size(1366, 1024),
    String openListId = 'list.a',
  }) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: TaskScaffold(openListId: openListId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('TC-UI-108 默认隐藏已完成；「显示」切换后可见', (tester) async {
    final repo = await seed();
    await pumpApp(tester, repo: repo);

    // 默认：已完成 open2 不在列表；大数字=未完成数；「N 项完成」计数仍在
    expect(find.text('香蕉'), findsOneWidget);
    expect(find.text('苹果'), findsNothing);
    expect(find.byKey(const ValueKey('remaining_count')), findsOneWidget);
    expect(find.text('1 项完成'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toggle_show_completed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示已完成').last);
    await tester.pumpAndSettle();

    expect(find.text('苹果'), findsOneWidget); // 已完成出现
  });

  testWidgets('TC-UI-111 排序「按标题」即时生效且不丢条目', (tester) async {
    final repo = await seed();
    await pumpApp(tester, repo: repo);

    // 开「显示已完成」让两条都可见，比较顺序才有信息量
    await tester.tap(find.byKey(const ValueKey('toggle_show_completed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示已完成').last);
    await tester.pumpAndSettle();

    // 手动序（插入序）：香蕉 在前
    expect(
      tester.getTopLeft(find.text('香蕉')).dy <
          tester.getTopLeft(find.text('苹果')).dy,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('sort_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按标题').last);
    await tester.pumpAndSettle();

    // 标题序：苹果（Apple）排在 香蕉（Banana）前
    expect(
      tester.getTopLeft(find.text('苹果')).dy <
          tester.getTopLeft(find.text('香蕉')).dy,
      isTrue,
    );
    expect(find.text('香蕉'), findsOneWidget); // 不丢条目
    expect(find.text('苹果'), findsOneWidget);
  });

  testWidgets('清除已完成：删除当前列表全部已完成顶层条目', (tester) async {
    final repo = await seed();
    await pumpApp(tester, repo: repo);

    expect(find.text('1 项完成'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clear_completed')));
    await tester.pumpAndSettle();

    final after = await repo.watchItems(listId: 'list.a').first;
    expect(after.where((e) => e.isCompleted), isEmpty);
    expect(after.where((e) => e.id == 'open1'), isNotEmpty); // 未完成保留
    expect(find.text('1 项完成'), findsNothing); // 计数清空
  });

  testWidgets('TC-UI-119 详情「移动到列表」：条目换列表且分区清空', (tester) async {
    final repo = await seed();
    // 给 open1 一个分区再移动，验证 sectionId 被清（TC-API-118 同口径）
    final open1 =
        (await repo.watchItems(listId: 'list.a').first).firstWhere((e) => e.id == 'open1');
    await repo.upsertItem(open1.copyWith(sectionId: 'sec-x'));

    // 宽屏三栏：选中 open1 → inspector
    await pumpApp(tester, repo: repo, openListId: 'list.a');
    await tester.tap(find.text('香蕉'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('move_to_list')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move_target_list.b')));
    await tester.pumpAndSettle();

    final inB = await repo.watchItems(listId: 'list.b').first;
    final moved = inB.firstWhere((e) => e.id == 'open1');
    expect(moved.sectionId, isNull); // 分区清空
    expect(moved.title, '香蕉');
    final inA = await repo.watchItems(listId: 'list.a').first;
    expect(inA.where((e) => e.id == 'open1'), isEmpty);
  });
}
