// #706：手动排序档拖到另一行前面 → 重写 sortOrder。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

Future<void> _dropBefore(
  WidgetTester tester, {
  required String draggedId,
  required String targetId,
}) async {
  final finder = find.byKey(ValueKey('reorder_target_$targetId'));
  expect(finder, findsOneWidget, reason: '落点 reorder_target_$targetId 要在');
  final target = tester.widget<DragTarget<String>>(finder);
  final onAccept = target.onAcceptWithDetails;
  expect(onAccept, isNotNull);
  onAccept!(
    DragTargetDetails<String>(
      data: draggedId,
      offset: tester.getCenter(finder),
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

  testWidgets('#706 拖 A 落到 B 前 → sortOrder 重排', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1.0;

    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.w', title: '工作'));
    await repo.upsertItem(
      const ReminderItem(id: 'a', listId: 'list.w', title: '甲', sortOrder: 0),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'b', listId: 'list.w', title: '乙', sortOrder: 1),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'c', listId: 'list.w', title: '丙', sortOrder: 2),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
        ],
        child: lifeTestHost(const TaskScaffold(openListId: 'list.w')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reorder_target_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('reorder_target_b')), findsOneWidget);

    // 把丙拖到甲前面：期望顺序 丙、甲、乙
    await _dropBefore(tester, draggedId: 'c', targetId: 'a');

    final items = await repo.watchItems(listId: 'list.w').first;
    final top = items.where((e) => e.parentId == null).toList()
      ..sort((x, y) {
        final by = x.sortOrder.compareTo(y.sortOrder);
        return by != 0 ? by : x.id.compareTo(y.id);
      });
    expect(top.map((e) => e.id).toList(), ['c', 'a', 'b']);
    expect(top.map((e) => e.sortOrder).toList(), [0, 1, 2]);
  });
}
