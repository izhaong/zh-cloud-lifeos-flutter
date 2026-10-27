import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  required ReminderRepository repo,
  Size size = const Size(1366, 1024),
  String? openListId,
  String? selectedItemId,
}) async {
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: lifeTestHost(
        TaskScaffold(openListId: openListId, selectedItemId: selectedItemId),
      ),
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

  testWidgets('今天视图时间分组：已过期/上午/下午/今晚', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.p', title: '个人'));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await repo.upsertItem(
      ReminderItem(
        id: 'over',
        listId: 'list.p',
        title: '过期项',
        dueAt: today
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 9)),
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'am',
        listId: 'list.p',
        title: '上午项',
        dueAt: today.add(const Duration(hours: 9)),
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'pm',
        listId: 'list.p',
        title: '下午项',
        dueAt: today.add(const Duration(hours: 14)),
      ),
    );
    await repo.upsertItem(
      ReminderItem(
        id: 'night',
        listId: 'list.p',
        title: '今晚项',
        dueAt: today.add(const Duration(hours: 20)),
      ),
    );

    await _pump(tester, repo: repo, openListId: 'smart.today');

    expect(find.byKey(const ValueKey('section_已过期')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_上午')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_下午')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_今晚')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('section_今天')),
      findsNothing,
      reason: '今天标题与列表标题重复，不渲染分区头',
    );
    expect(find.text('过期项'), findsOneWidget);
    expect(find.text('上午项'), findsOneWidget);
    expect(find.text('下午项'), findsOneWidget);
    expect(find.text('今晚项'), findsOneWidget);
  });

  testWidgets('详情日期与时间可编辑并回写 dueAt', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.p', title: '个人'));
    await repo.upsertItem(
      const ReminderItem(id: 'i1', listId: 'list.p', title: '待排期'),
    );

    await _pump(tester, repo: repo, openListId: 'list.p', selectedItemId: 'i1');

    await tester.tap(find.byKey(const ValueKey('due_at_row')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('due_at_editor')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('due_at_confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('detail_save')));
    await tester.pumpAndSettle();

    final item = (await repo.watchItems(listId: 'list.p').first).singleWhere(
      (e) => e.id == 'i1',
    );
    expect(item.dueAt, isNotNull, reason: '确认后保存必须回写 dueAt');
  });

  testWidgets('详情日期清除：dueAt 置空', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.p', title: '个人'));
    await repo.upsertItem(
      ReminderItem(
        id: 'i1',
        listId: 'list.p',
        title: '有日期',
        dueAt: DateTime.now(),
      ),
    );

    await _pump(tester, repo: repo, openListId: 'list.p', selectedItemId: 'i1');

    await tester.tap(find.byKey(const ValueKey('due_at_row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('due_at_clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('detail_save')));
    await tester.pumpAndSettle();

    final item = (await repo.watchItems(listId: 'list.p').first).singleWhere(
      (e) => e.id == 'i1',
    );
    expect(item.dueAt, isNull, reason: '清除后 dueAt 必须为 null');
  });

  testWidgets('紧凑端左滑删除进最近删除', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.p', title: '个人'));
    await repo.upsertItem(
      const ReminderItem(id: 'i1', listId: 'list.p', title: '要删除的'),
    );

    await _pump(
      tester,
      repo: repo,
      size: const Size(375, 812),
      openListId: 'list.p',
    );

    await tester.drag(
      find.byKey(const ValueKey('dismiss_i1')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    final trash = await repo.watchItems(listId: 'smart.trash').first;
    expect(trash.map((e) => e.id), contains('i1'));
  });

  test('回收站计数含已完成删除项', () async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.p', title: '个人'));
    await repo.upsertItem(
      const ReminderItem(id: 'i1', listId: 'list.p', title: '已完成后删除'),
    );
    await repo.toggleCompleted('i1');
    await repo.deleteItem('i1');

    final lists = await repo.watchLists().first;
    expect(
      lists.singleWhere((l) => l.id == 'smart.trash').itemCount,
      1,
      reason: '已完成删除项也必须计入最近删除',
    );
  });

  testWidgets('详情「删除提醒」进最近删除', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.p', title: '个人'));
    await repo.upsertItem(
      const ReminderItem(id: 'i1', listId: 'list.p', title: '删除我'),
    );

    await _pump(
      tester,
      repo: repo,
      size: const Size(1366, 1400),
      openListId: 'list.p',
      selectedItemId: 'i1',
    );

    final delete = find.byKey(const ValueKey('detail_delete'));
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();

    final trash = await repo.watchItems(listId: 'smart.trash').first;
    expect(trash.map((e) => e.id), contains('i1'));
  });
}
