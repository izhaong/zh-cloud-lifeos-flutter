import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'support/life_test_app.dart';

/// TC-UI-308（主区工具条）：旗标行为 + 无分享按钮负向断言。
///
/// 对等矩阵裁定（issue 关闭口径）：本平台「分享」入口不存在，旗标只在行内
/// 切换（`row_flag_<id>`）与详情面板开关两处。因此：
///  - 旗标：行内点击应切换 `isFlagged`（行为测试）；
///  - 分享：用例改为负向断言——整个任务 UI 不应出现「分享」文案与分享按钮。
void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<InMemoryReminderRepository> _seed() async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '列表A'));
    await repo.upsertItem(
      const ReminderItem(id: 'open1', listId: 'list.a', title: '香蕉'),
    );
    return repo;
  }

  Future<void> _pump(
    WidgetTester tester,
    ReminderRepository repo, {
    String openListId = 'list.a',
    Size size = const Size(1366, 1024),
  }) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = size;
    view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: TaskScaffold(openListId: openListId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('TC-UI-308 行内旗标点击切换 isFlagged', (tester) async {
    final repo = await _seed();
    await _pump(tester, repo);

    Future<bool> _flagged() async {
      final all = await repo.watchItems().first;
      return all.firstWhere((e) => e.id == 'open1').isFlagged;
    }

    expect(await _flagged(), isFalse, reason: '初始未标记');

    // 行内旗标按钮：row_flag_<id>
    final flagBtn = find.byKey(const Key('row_flag_open1'));
    expect(flagBtn, findsOneWidget, reason: '行内旗标按钮存在');
    await tester.tap(flagBtn);
    await tester.pumpAndSettle();
    expect(await _flagged(), isTrue, reason: '点击后应标记为旗标');

    // 再点一次取消
    await tester.tap(flagBtn);
    await tester.pumpAndSettle();
    expect(await _flagged(), isFalse, reason: '再次点击应取消标记');
  });

  testWidgets('TC-UI-308 本平台无「分享」入口（负向断言）', (tester) async {
    final repo = await _seed();
    await _pump(tester, repo);

    // 任务 UI 不应出现「分享」文案
    expect(find.text('分享'), findsNothing,
        reason: '对等矩阵裁定：本平台无分享入口');
    // 不应存在分享按钮（即便未来误加 key 也能拦住）
    expect(find.byKey(const Key('share_button')), findsNothing,
        reason: '无 share_button');
    // 工具条（排序/显示/清除）存在，但不含分享
    expect(find.text('排序'), findsWidgets);
    expect(find.text('显示'), findsWidgets);
  });
}
