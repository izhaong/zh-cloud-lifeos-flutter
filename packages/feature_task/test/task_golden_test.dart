import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 三档 golden 基线（#333）。挂钟经 [clockProvider] 钉死，图才确定——
/// 否则「已过期/今天」分组随执行日期漂移（与 calendar #331 同一类问题）。
void main() {
  final fixed = DateTime(2026, 10, 26, 9, 30);

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryReminderRepository()
      // #333 审查指出：`smart.today` 的过滤用仓储内部时钟，不设它就会与分组时钟脱节
      // （例如在夹具日期之前跑，「周报」会被滤掉）。
      ..nowForTest = fixed;
    await repo.upsertItem(
      ReminderItem(
        id: 'r-overdue',
        listId: 'list.default',
        title: '早餐',
        dueAt: DateTime(2026, 10, 25, 8),
        createdAt: DateTime(2026, 10, 25, 8),
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'r-today',
        listId: 'list.default',
        title: '周报',
        dueAt: DateTime(2026, 10, 26, 10),
        createdAt: DateTime(2026, 10, 26, 9),
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'r-nodate',
        listId: 'list.default',
        title: '打个电话',
        createdAt: DateTime(2026, 10, 26, 9),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => fixed),
        ],
        // 钉在「今天」智能列表：这条路径会按 now 分桶（已过期/今天/上午/下午），
        // 才是挂钟敏感面——默认列表页不分组，换日期也不会红（第一版就栽在这）。
        child: const MaterialApp(home: TaskScaffold(openListId: 'smart.today')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('桌面 1280 暗色（golden 基线；同夹具只改明暗）', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpAt(tester, const Size(1280, 800));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desktop_1280_task_dark.png'),
    );
  });

  testWidgets('iPhone 375（golden 基线；挂钟注入固定 2026-10-26）', (tester) async {
    await pumpAt(tester, const Size(375, 812));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/iphone_375_task.png'),
    );
  });

  testWidgets('iPad 834（golden 基线；挂钟注入固定 2026-10-26）', (tester) async {
    await pumpAt(tester, const Size(834, 1112));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/ipad_834_task.png'),
    );
  });

  testWidgets('桌面 1280（golden 基线；挂钟注入固定 2026-10-26）', (tester) async {
    await pumpAt(tester, const Size(1280, 800));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desktop_1280_task.png'),
    );
  });
}
