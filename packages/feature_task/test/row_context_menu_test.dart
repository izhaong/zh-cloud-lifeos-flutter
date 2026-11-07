import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

/// parity#675：macOS 右键提醒事项行应弹**锚定在光标处**的桌面上下文菜单，
/// 而不是贴底的移动端操作表、也不该只剩「删除提醒 / 取消」两项。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<InMemoryReminderRepository> pumpList(WidgetTester tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '列表A'));
    await repo.upsertItem(
      const ReminderItem(id: 'r1', listId: 'list.a', title: '买牛奶'),
    );
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1440, 1000)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(const TaskScaffold(openListId: 'list.a')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return repo;
  }

  Future<Offset> rightClickRow(WidgetTester tester) async {
    final at = tester.getCenter(find.text('买牛奶'));
    await tester.tapAt(at, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    return at;
  }

  testWidgets('右键弹出完整上下文菜单，而非只有删除的操作表', (tester) async {
    await pumpList(tester);
    await rightClickRow(tester);

    for (final key in const [
      'row_ctx_complete_r1',
      'row_ctx_flag_r1',
      'row_ctx_priority_0_r1',
      'row_ctx_priority_9_r1',
      'row_ctx_info_r1',
      'row_ctx_delete_r1',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: '缺 $key');
    }
    expect(find.text('删除提醒'), findsNothing, reason: '旧的底部操作表不该再出现');
  });

  testWidgets('菜单锚定在光标附近，不是贴窗口底边的通栏', (tester) async {
    await pumpList(tester);
    final at = await rightClickRow(tester);
    final menuItem = tester.getRect(find.byKey(const ValueKey('row_ctx_complete_r1')));
    expect((menuItem.top - at.dy).abs(), lessThan(200),
        reason: '首项应在点击处附近（实际 top=${menuItem.top}, 点击 y=${at.dy}）');
    expect(menuItem.width, lessThan(600), reason: '桌面菜单不是通栏宽度');
  });

  testWidgets('菜单项真的生效：完成、旗标、优先级、删除', (tester) async {
    final repo = await pumpList(tester);
    Future<ReminderItem?> current() async =>
        (await repo.watchItems(listId: 'list.a', includeCompleted: true).first)
            .where((e) => e.id == 'r1')
            .firstOrNull;

    await rightClickRow(tester);
    await tester.tap(find.byKey(const ValueKey('row_ctx_priority_9_r1')));
    await tester.pumpAndSettle();
    expect((await current())!.priority, 9);

    await rightClickRow(tester);
    await tester.tap(find.byKey(const ValueKey('row_ctx_flag_r1')));
    await tester.pumpAndSettle();
    expect((await current())!.isFlagged, isTrue);

    await rightClickRow(tester);
    await tester.tap(find.byKey(const ValueKey('row_ctx_delete_r1')));
    await tester.pumpAndSettle();
    expect(await current(), isNull, reason: '删除后不在列表里');
  });
}
