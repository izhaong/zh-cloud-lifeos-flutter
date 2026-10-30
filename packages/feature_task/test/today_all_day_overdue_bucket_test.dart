// #474 / 矩阵 A9·A11·B16 / TC-UI-101（补段内落桶断言）：
// 「今天」智能列表的「已过期」段必须同时收定时与**全天**的过期项；
// 修复前过期全天项会掉进「今天」无时段区（视图分桶漏判，仓库层本该已纳入）。
//
// 判红设计：只放过期**全天**项（不放过期定时项），修复前「已过期」桶为空、
// 分区头随空桶一起消失 → `section_已过期` findsNothing，断言必红。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

Future<void> _pumpToday(
  WidgetTester tester,
  ReminderRepository repo,
  DateTime now,
) async {
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = const Size(1280, 900)
    ..devicePixelRatio = 1.0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => now),
      ],
      child: lifeTestHost(const TaskScaffold(openListId: 'smart.today')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('「今天」视图：过期全天项归「已过期」段，今天的全天项留在今天', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.p', title: '工作'));
    // #484：定时项按时刻判过期；钉住时钟并让「今天上午项」落在未来，
    // 避免午后跑测试时 09:00 被归入「已过期」而干扰本用例的全天归桶断言。
    final now = DateTime(2026, 10, 29, 9, 30);
    repo.nowProvider = () => now;
    final day = DateTime(now.year, now.month, now.day);
    final yesterday = day.subtract(const Duration(days: 1));

    await repo.upsertItem(
      ReminderItem(
        id: 'all-day-overdue',
        listId: 'list.p',
        title: '昨天的全天项',
        dueAt: yesterday,
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'all-day-today',
        listId: 'list.p',
        title: '今天的全天项',
        dueAt: day,
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'timed-today',
        listId: 'list.p',
        title: '今天上午项',
        dueAt: day.add(const Duration(hours: 10)),
      ),
    );

    await _pumpToday(tester, repo, now);

    expect(
      find.byKey(const ValueKey('section_已过期')),
      findsOneWidget,
      reason: '过期全天项必须撑起「已过期」分区（#474）',
    );
    expect(find.text('昨天的全天项'), findsOneWidget);
    expect(find.text('今天的全天项'), findsOneWidget);
    expect(find.text('今天上午项'), findsOneWidget);

    final overdueHeaderY =
        tester.getTopLeft(find.byKey(const ValueKey('section_已过期'))).dy;
    final allDayOverdueY = tester.getTopLeft(find.text('昨天的全天项')).dy;
    final allDayTodayY = tester.getTopLeft(find.text('今天的全天项')).dy;
    final morningHeaderY =
        tester.getTopLeft(find.byKey(const ValueKey('section_上午'))).dy;

    expect(
      overdueHeaderY,
      lessThan(allDayOverdueY),
      reason: '过期全天项必须落在「已过期」分区头之下',
    );
    expect(
      allDayOverdueY,
      lessThan(allDayTodayY),
      reason: '过期全天项不能掉进「今天」无时段区（#474）',
    );
    expect(
      allDayTodayY,
      lessThan(morningHeaderY),
      reason: '今天全天项留在「今天」桶，不挤进上午分区',
    );
  });
}
