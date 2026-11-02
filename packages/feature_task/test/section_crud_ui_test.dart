// #533：分区要有**生产入口**。此前 kernel 的 upsertSection / reorderSection /
// deleteSection 在产品代码里零调用，列表「更多」菜单只有一条置灰的
// 「按分区整理（规划）」。本文件从 UI 打通新建 / 重命名 / 排序 / 删除，
// 并断言那条置灰占位已消失。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

Future<List<ReminderSection>> _sectionsOf(
  ReminderRepository repo,
  String listId,
) async {
  final lists = await repo.watchLists().first;
  return lists.firstWhere((e) => e.id == listId).sections;
}

Future<void> _pump(WidgetTester tester, ReminderRepository repo) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: lifeTestHost(const TaskScaffold(openListId: 'list.work')),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openMoreMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('list_more_menu')));
  await tester.pumpAndSettle();
}

Future<void> _newSection(WidgetTester tester, String title) async {
  await _openMoreMenu(tester);
  await tester.tap(find.text('新建分区'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('new_section_name')), title);
  await tester.tap(find.byKey(const ValueKey('new_section_submit')));
  await tester.pumpAndSettle();
}

Future<void> _openEditor(WidgetTester tester) async {
  await _openMoreMenu(tester);
  await tester.tap(find.text('编辑分区…'));
  await tester.pumpAndSettle();
}

void main() {
  late InMemoryReminderRepository repo;

  setUp(() async {
    repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
    await repo.upsertItem(
      const ReminderItem(id: 'i-1', listId: 'list.work', title: '买牛奶'),
    );
  });

  testWidgets('#533 新建分区写进仓库并出现在列表头；置灰占位消失', (tester) async {
    await _pump(tester, repo);

    await _openMoreMenu(tester);
    expect(find.text('按分区整理（规划）'), findsNothing, reason: '原「规划」占位应被真入口替换');
    expect(find.text('新建分区'), findsOneWidget);
    await _newSection(tester, '分区一');

    expect(
      (await _sectionsOf(repo, 'list.work')).map((e) => e.title).toList(),
      ['分区一'],
    );
    expect(
      find.byKey(const ValueKey('section_分区一')),
      findsOneWidget,
      reason: '新分区要立刻成为列表里的分区头',
    );
  });

  testWidgets('#533 编辑分区：重命名 / 上下移 / 删除都落到仓库', (tester) async {
    await _pump(tester, repo);
    await _newSection(tester, '分区一');
    await _newSection(tester, '分区二');
    var sections = await _sectionsOf(repo, 'list.work');
    expect(sections.map((e) => e.title).toList(), ['分区一', '分区二']);
    final id1 = sections.first.id;
    final id2 = sections.last.id;

    await _openEditor(tester);
    // 重命名分区二
    await tester.enterText(find.byKey(ValueKey('section_rename_$id2')), '采买');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      (await _sectionsOf(repo, 'list.work')).map((e) => e.title).toList(),
      ['分区一', '采买'],
    );

    // 上移：把第二项换到最前
    await tester.tap(find.byKey(ValueKey('section_up_$id2')));
    await tester.pumpAndSettle();
    expect((await _sectionsOf(repo, 'list.work')).map((e) => e.id).toList(), [
      id2,
      id1,
    ]);

    // 删除第一项（二次确认后级联回落）
    await tester.tap(find.byKey(ValueKey('section_delete_$id1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('section_delete_confirm')));
    await tester.pumpAndSettle();
    expect((await _sectionsOf(repo, 'list.work')).map((e) => e.id).toList(), [
      id2,
    ]);
    expect(find.byKey(const ValueKey('section_分区一')), findsNothing);
  });
}
