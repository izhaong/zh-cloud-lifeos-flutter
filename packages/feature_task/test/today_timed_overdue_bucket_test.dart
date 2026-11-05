// #484 / 矩阵 A9·B16 / TC-UI-101（定时项过期落桶）：
// 今天视图里，dueAt 早于当前时刻的**定时**提醒必须进「已过期」段，
// 不能挂在「上午/下午/今晚」；全天项仍只按日期判过期（#474）。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

final _now = DateTime(2026, 10, 29, 9, 30);

Future<void> _pumpToday(WidgetTester tester, ReminderRepository repo) async {
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
    ..physicalSize = const Size(1280, 900)
    ..devicePixelRatio = 1.0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: lifeTestHost(const TaskScaffold(openListId: 'smart.today')),
    ),
  );
  await tester.pumpAndSettle();
  view.resetPhysicalSize();
  view.resetDevicePixelRatio();
}

void main() {
  testWidgets('「今天」视图：定时项过了时刻进「已过期」，未到的留在时段桶', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    repo.nowProvider = () => _now;
    await repo.upsertList(const ReminderList(id: 'list.p', title: '工作'));

    await repo.upsertItem(
      ReminderItem(
        id: 'timed-past',
        listId: 'list.p',
        title: '今天的已过时刻',
        dueAt: DateTime(2026, 10, 29, 9),
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'timed-future',
        listId: 'list.p',
        title: '今天的未来时刻',
        dueAt: DateTime(2026, 10, 29, 10),
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'all-day-today',
        listId: 'list.p',
        title: '今天的全天项',
        dueAt: DateTime(2026, 10, 29),
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'all-day-yesterday',
        listId: 'list.p',
        title: '昨天的全天项',
        dueAt: DateTime(2026, 10, 28),
      ),
    );

    await _pumpToday(tester, repo);

    final overdueHeaderY =
        tester.getTopLeft(find.byKey(const ValueKey('section_已过期'))).dy;
    final morningHeaderY =
        tester.getTopLeft(find.byKey(const ValueKey('section_上午'))).dy;
    final timedPastY = tester.getTopLeft(find.text('今天的已过时刻')).dy;
    final timedFutureY = tester.getTopLeft(find.text('今天的未来时刻')).dy;
    final allDayTodayY = tester.getTopLeft(find.text('今天的全天项')).dy;
    final allDayYesterdayY = tester.getTopLeft(find.text('昨天的全天项')).dy;

    expect(
      timedPastY,
      greaterThan(overdueHeaderY),
      reason: '已过时刻的定时项必须在「已过期」分区头之下（#484）',
    );
    expect(
      timedPastY,
      lessThan(morningHeaderY),
      reason: '已过时刻的定时项不能留在「上午」分区（#484）',
    );
    expect(
      timedFutureY,
      greaterThan(morningHeaderY),
      reason: '未到时刻的定时项仍在「上午」分区',
    );
    expect(
      allDayYesterdayY,
      lessThan(allDayTodayY),
      reason: '昨天的全天项在「已过期」，今天的全天项在「今天」桶',
    );
    expect(
      allDayTodayY,
      lessThan(morningHeaderY),
      reason: '今天的全天项不该挤进「上午」',
    );
  });
}
