import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SidebarHost extends ConsumerWidget {
  const _SidebarHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(reminderListsProvider).asData?.value ??
        const <ReminderList>[];
    return TaskSidebar(
      lists: lists,
      selectedListId: null,
      onSelect: (_) {},
    );
  }
}

Future<InMemoryReminderRepository> _repoWithList() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(
    const ReminderList(
      id: 'list.personal',
      title: '个人',
      colorArgb: 0xFF34C759,
    ),
  );
  return repo;
}

void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('侧栏：7 张彩色智能卡 + 建议列表 + 我的列表图标', (tester) async {
    final repo = await _repoWithList();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 320, height: 760, child: _SidebarHost()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final id in [
      'smart.today',
      'smart.scheduled',
      'smart.all',
      'smart.flagged',
      'smart.urgent',
      'smart.completed',
    ]) {
      expect(find.byKey(ValueKey('smart_card_$id')), findsOneWidget,
          reason: '缺少智能卡 $id');
    }
    expect(find.byKey(const ValueKey('smart_card_smart.assigned')), findsNothing,
        reason: '分配事项按裁定不出现在任务 UI（TC-API-121 降级口径；负向门禁）');
    expect(find.text('分配事项'), findsNothing);
    expect(find.byKey(const ValueKey('smart_card_smart.trash')), findsNothing,
        reason: '最近删除不是卡片，是列表行');
    expect(find.byKey(const ValueKey('my_list_list.personal')), findsOneWidget);
    expect(find.byKey(const ValueKey('my_list_smart.trash')), findsOneWidget);
    expect(find.byKey(const ValueKey('suggested_grocery')), findsOneWidget);
  });

  testWidgets('建议列表点击后创建真实 grocery 列表并消失', (tester) async {
    final repo = await _repoWithList();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 320, height: 760, child: _SidebarHost()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('suggested_grocery')));
    await tester.pumpAndSettle();

    final lists = await repo.watchLists().first;
    final grocery = lists.where(
      (e) => e.title == '日常采购' && e.listType == ReminderListType.grocery,
    );
    expect(grocery.length, 1, reason: '点击应创建 grocery 列表');
    expect(find.byKey(const ValueKey('suggested_grocery')), findsNothing);
    expect(find.text('日常采购'), findsOneWidget);
  });

  testWidgets('桌面侧栏宽度随窗口 23.5% 缩放', (tester) async {
    final repo = await _repoWithList();
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;

    Future<void> pumpAt(Size size) async {
      view
        ..physicalSize = size
        ..devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: TaskScaffold(openListId: 'list.personal'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpAt(const Size(1024, 768));
    expect(
      tester.getSize(find.byType(TaskSidebar)).width,
      closeTo(240.64, 0.5),
    );

    await pumpAt(const Size(1280, 800));
    expect(
      tester.getSize(find.byType(TaskSidebar)).width,
      closeTo(300.8, 0.5),
    );
  });
}
