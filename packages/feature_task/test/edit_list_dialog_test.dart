// #491 / 矩阵行 13 / TC-UI-115：
// 紧凑首页「⋯ 编辑列表」不再是「规划占位」，可改名/改颜色/改类型并落库。
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

Future<InMemoryReminderRepository> _seed() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(
    const ReminderList(id: 'list.a', title: '个人', colorArgb: 0xFF007AFF),
  );
  await repo.upsertList(
    const ReminderList(id: 'list.b', title: '工作', colorArgb: 0xFF34C759),
  );
  return repo;
}

Future<void> _pumpHome(
  WidgetTester tester,
  InMemoryReminderRepository repo,
) async {
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = const Size(420, 900)
    ..devicePixelRatio = 1.0;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: lifeTestHost(const TaskScaffold()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('紧凑首页编辑列表：改名 + 换色 + 改类型并落库（#491）', (tester) async {
    final repo = await _seed();
    await _pumpHome(tester, repo);

    await tester.tap(find.byKey(const ValueKey('home_edit_placeholder')));
    await tester.pumpAndSettle();
    expect(find.text('规划占位'), findsNothing, reason: '占位文案必须消失');

    await tester.tap(find.byKey(const ValueKey('edit_pick_list.a')));
    await tester.pumpAndSettle();

    final name = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('edit_list_name')),
    );
    expect(name.controller!.text, '个人', reason: '编辑框要带出当前名称');

    await tester.enterText(
      find.byKey(const ValueKey('edit_list_name')),
      '家庭',
    );
    await tester.tap(find.byKey(const ValueKey('edit_color_${0xFFFF9500}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日常采购'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit_list_submit')));
    await tester.pumpAndSettle();

    final lists = await repo.watchLists().first;
    final edited = lists.firstWhere((l) => l.id == 'list.a');
    expect(edited.title, '家庭');
    expect(edited.colorArgb, 0xFFFF9500);
    expect(edited.listType, ReminderListType.grocery);
    expect(find.text('家庭'), findsWidgets, reason: '首页立即反映新名称');
  });
}
