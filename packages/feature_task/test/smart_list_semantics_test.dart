import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-UI-102/103/104：计划 / 全部 / 旗标。
///
/// 语义以 kernel `_filter` 为准：
/// - 计划：未完成且 dueAt 非空（含今天与已过期）
/// - 全部：未完成（含无日期）
/// - 已旗标：未完成且 isFlagged
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('TC-UI-102/103/104 首页计数与点入命中集', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '甲'));
    await repo.upsertList(const ReminderList(id: 'list.b', title: '乙'));
    await repo.upsertItem(ReminderItem(
      id: 'today',
      listId: 'list.a',
      title: '今天旗标',
      dueAt: today,
      isFlagged: true,
    ));
    await repo.upsertItem(ReminderItem(
      id: 'tomorrow',
      listId: 'list.b',
      title: '明天事项',
      dueAt: today.add(const Duration(days: 1)),
    ));
    await repo.upsertItem(ReminderItem(
      id: 'yesterday',
      listId: 'list.a',
      title: '昨天过期',
      dueAt: today.subtract(const Duration(days: 1)),
    ));
    await repo.upsertItem(const ReminderItem(
      id: 'nodate',
      listId: 'list.a',
      title: '无日期事项',
    ));
    await repo.upsertItem(ReminderItem(
      id: 'done',
      listId: 'list.a',
      title: '已完成旗标',
      dueAt: today,
      isFlagged: true,
      isCompleted: true,
    ));

    Future<void> pump({String? openListId}) async {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view
        ..physicalSize = const Size(375, 1200)
        ..devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: TaskScaffold(openListId: openListId)),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder cardCount(String title, String count) {
      final card = find.ancestor(
        of: find.text(title),
        matching: find.byType(CupertinoButton),
      );
      return find.descendant(of: card, matching: find.text(count));
    }

    await pump();
    expect(cardCount('计划', '3'), findsOneWidget);
    expect(cardCount('全部', '4'), findsOneWidget);
    expect(cardCount('旗标', '1'), findsOneWidget);

    await pump(openListId: 'smart.scheduled');
    expect(find.text('今天旗标'), findsOneWidget);
    expect(find.text('明天事项'), findsOneWidget);
    expect(find.text('昨天过期'), findsOneWidget);
    expect(find.text('无日期事项'), findsNothing);
    expect(find.text('已完成旗标'), findsNothing);

    await pump(openListId: 'smart.all');
    expect(find.text('无日期事项'), findsOneWidget);
    expect(find.text('已完成旗标'), findsNothing);

    await pump(openListId: 'smart.flagged');
    expect(find.text('今天旗标'), findsOneWidget);
    expect(find.text('明天事项'), findsNothing);
    expect(find.text('已完成旗标'), findsNothing);
  });
}
