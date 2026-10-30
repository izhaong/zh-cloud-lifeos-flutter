// #479：「计划」视图日期头形态——绝对日期带星期后缀（11月2日 周一），
// 近邻日用相对标签：前天(D-2)/昨天(D-1)/今天/明天(D+1)/后天(D+2)；
// 更早（≤D-3）维持「已过期」聚合（#475 排序语义不变）。
// Apple 对照：docs/ui-evidence/2026-10-29-task-parity/03-apple-scheduled-view.png
// （10月23日 周五…前天/今天/明天/后天/11月1日 周日）。
// #500：日差用 UTC 午夜对午夜，DST 回拨日（25 小时）不再错算「明天」。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

/// 2026-10-29 是周四。
final _clock = DateTime(2026, 10, 29, 9, 30);

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('#479 计划视图按日标签：前天/昨天/后天/绝对日期带星期', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.p', title: '个人'));
    ReminderItem item(String id, DateTime due) =>
        ReminderItem(id: id, listId: 'list.p', title: '项$id', dueAt: due);
    await repo.upsertItem(item('d3', DateTime(2026, 10, 26, 10))); // ≤D-3 → 已过期
    await repo.upsertItem(item('d2', DateTime(2026, 10, 27, 10))); // D-2 → 前天
    await repo.upsertItem(item('d1', DateTime(2026, 10, 28, 10))); // D-1 → 昨天
    await repo.upsertItem(item('t0', DateTime(2026, 10, 29, 10))); // D0 → 今天
    await repo.upsertItem(item('p2', DateTime(2026, 10, 31, 10))); // D+2 → 后天
    await repo.upsertItem(item('p4', DateTime(2026, 11, 2, 10))); // D+4 → 11月2日 周一

    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => _clock),
        ],
        child: lifeTestHost(const TaskScaffold(openListId: 'smart.scheduled')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section_已过期')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_前天')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_昨天')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_今天')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_后天')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_11月2日 周一')), findsOneWidget,
        reason: '绝对日期头带星期后缀（#479①）');

    // 顺序（#475 语义延续）：已过期 → 前天 → 昨天 → 今天 → 后天 → 11月2日 周一
    final headerOrder = <String>[];
    for (final key in [
      'section_已过期',
      'section_前天',
      'section_昨天',
      'section_今天',
      'section_后天',
      'section_11月2日 周一',
    ]) {
      final f = find.byKey(ValueKey(key));
      headerOrder.add(tester.getTopLeft(f).dy.toString());
    }
    final ys = headerOrder.map(double.parse).toList();
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]),
          reason: '分区自上而下按日期升序（第 $i 项错位）');
    }
  });
}
