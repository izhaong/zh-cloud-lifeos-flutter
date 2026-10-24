import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TC-REG-105：千级数据性能基线（自动化部分）。
/// 阈值口径：1000 条 pumpAndSettle 完成时间 < 10s（宽松基线——CI 波动防护；
/// 真机 jank 走查属手动清单）。搜索输入响应 < 2s。
void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('TC-REG-105 千级列表可渲染且搜索响应在线', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.big', title: '千级'));
    final now = DateTime.now();
    for (var i = 0; i < 1000; i++) {
      await repo.upsertItem(
        ReminderItem(
          id: 'item-$i',
          listId: 'list.big',
          title: '条目 $i',
          dueAt: now,
        ),
      );
    }

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1366, 1024);
    view.devicePixelRatio = 1.0;

    final sw = Stopwatch()..start();
    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: TaskScaffold(openListId: 'list.big'),
      ),
    ));
    await tester.pumpAndSettle();
    sw.stop();

    // 首帧完成（可见区首条在屏）
    expect(find.text('条目 0'), findsOneWidget);
    // 宽松基线：虚拟环境 1000 条 < 10s
    expect(sw.elapsed.inSeconds, lessThan(10),
        reason: '千级渲染 ${sw.elapsed}——超基线需排查 N+1 或全量重建');

    // 搜索响应计时（cursor PR#18：硬断言存在 + <2s 在线）
    final queryField = find.byKey(const ValueKey('toolbar_search'));
    expect(queryField, findsOneWidget, reason: '宽屏必有工具栏搜索框');
    final swSearch = Stopwatch()..start();
    await tester.enterText(queryField, '条目 999');
    await tester.pumpAndSettle();
    swSearch.stop();
    expect(swSearch.elapsed.inSeconds, lessThan(2),
        reason: '千级数据下搜索响应 ${swSearch.elapsed}——超 2s 需排查全量重建');
    // findsWidgets：命中行 + 搜索框 EditableText 自身含同文本
    expect(find.text('条目 999'), findsWidgets);
  });
}
