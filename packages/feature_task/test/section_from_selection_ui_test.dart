// flutter #567（TC-UI-321）：「用所选项目新建分区（⌃⌘N）」的 UI 半面。
//
// 三件事各自要钉住，缺一件这单就不算落地：
//   ① 先要能**多选**（本仓此前只有单选，长按一行进入选择态）；
//   ② 一次动作 ⇒ **一次**原子写（`createSectionWithTasks` 1 次，`upsertItem`/`upsertSection` 0 次）；
//   ③ 未选中时列表 ⋯ 菜单那条**置灰**（点了没有任何反应），
//      而 macOS 菜单按 #537 定的不变量只投命令，由 feature_task 给可见提示且不写数据。
import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

/// 计数仓库：判据②只能靠计数断言，看结果形状是量不出「写了几次」的。
/// （InMemory 是 `final class`，不能 extend ⇒ 一律委托，形状抄 `phase2_ui_test` 的 `_CountingRepo`。）
class _SpyRepo implements ReminderRepository {
  _SpyRepo(this._inner);

  final InMemoryReminderRepository _inner;
  int createWithTasks = 0;
  int sectionWrites = 0;
  int itemWrites = 0;

  @override
  bool checkDayRollover() => _inner.checkDayRollover();

  @override
  Stream<List<ReminderList>> watchLists() => _inner.watchLists();

  @override
  Stream<List<ReminderItem>> watchItems({
    String? listId,
    bool includeCompleted = false,
  }) => _inner.watchItems(listId: listId);

  @override
  Future<void> upsertItem(ReminderItem item) async {
    itemWrites++;
    await _inner.upsertItem(item);
  }

  @override
  Future<void> toggleCompleted(String itemId) => _inner.toggleCompleted(itemId);

  @override
  Future<void> toggleFlagged(String itemId) => _inner.toggleFlagged(itemId);

  @override
  Future<void> moveItem(String itemId, String targetListId) =>
      _inner.moveItem(itemId, targetListId);

  @override
  Future<void> deleteItem(String itemId) => _inner.deleteItem(itemId);

  @override
  Future<void> restoreItem(String itemId) => _inner.restoreItem(itemId);

  @override
  Future<int> purgeExpiredDeleted() => _inner.purgeExpiredDeleted();

  @override
  Future<void> upsertList(ReminderList list) => _inner.upsertList(list);

  @override
  Future<void> deleteList(String listId) => _inner.deleteList(listId);

  @override
  Future<void> upsertSection({
    required String listId,
    required ReminderSection section,
  }) async {
    sectionWrites++;
    await _inner.upsertSection(listId: listId, section: section);
  }

  @override
  Future<void> reorderSection({
    required String listId,
    required List<String> sectionIds,
  }) => _inner.reorderSection(listId: listId, sectionIds: sectionIds);

  @override
  Future<void> deleteSection({
    required String listId,
    required String sectionId,
  }) => _inner.deleteSection(listId: listId, sectionId: sectionId);

  @override
  Future<void> createSectionWithTasks({
    required String listId,
    required ReminderSection section,
    required List<String> itemIds,
  }) async {
    createWithTasks++;
    await _inner.createSectionWithTasks(
      listId: listId,
      section: section,
      itemIds: itemIds,
    );
  }
}

void main() {
  late InMemoryReminderRepository inner;
  late _SpyRepo repo;
  late ValueNotifier<LifeMenuAction?> commands;

  setUp(() async {
    inner = InMemoryReminderRepository(seedSampleData: false);
    inner.disposeDayRolloverWatch(); // 定时器会留下「A Timer is still pending」
    repo = _SpyRepo(inner);
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
    for (final (id, title) in [('i1', '甲'), ('i2', '乙'), ('i3', '丙')]) {
      await repo.upsertItem(ReminderItem(id: id, listId: 'list.work', title: title));
    }
    // 计数从「种子之后」起算：setUp 里的 3 次 upsertItem 不是用户动作。
    // 计数从「种子之后」起算：setUp 里的 3 次 upsertItem 不是用户动作。
    repo.itemWrites = 0;
    repo.sectionWrites = 0;
    commands = ValueNotifier<LifeMenuAction?>(null);
    addTearDown(commands.dispose);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          lifeMenuCommandsProvider.overrideWithValue(commands),
        ],
        child: lifeTestHost(const TaskScaffold(openListId: 'list.work')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMoreMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('list_more_menu')));
    await tester.pumpAndSettle();
  }

  Future<List<ReminderSection>> sections() async =>
      (await repo.watchLists().first)
          .firstWhere((e) => e.id == 'list.work')
          .sections;

  Future<String?> sectionIdOf(String itemId) async {
    final items = await repo.watchItems(listId: 'list.work').first;
    return items.firstWhere((e) => e.id == itemId).sectionId;
  }

  testWidgets('TC-UI-321 长按进入选择态 ⇒ 勾两条 ⇒ 一次原子写产出 1 分区 + 2 归属', (tester) async {
    await pump(tester);

    // 选择态之前：不该有勾选靶（证明多选是新加的，不是抄现成的）
    expect(find.byKey(const ValueKey('select_i1')), findsNothing);

    await tester.longPress(find.byKey(const ValueKey('row_long_press_i1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('select_i1')), findsOneWidget,
        reason: '长按进入选择态，勾上那一条');

    await tester.tap(find.byKey(const ValueKey('select_i2')));
    await tester.pumpAndSettle();

    await openMoreMenu(tester);
    await tester.tap(find.text('用所选项目新建分区'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('new_section_name')), '采购');
    await tester.tap(find.byKey(const ValueKey('new_section_submit')));
    await tester.pumpAndSettle();

    expect(repo.createWithTasks, 1, reason: '判据②：一次用户动作一次落库');
    expect(repo.sectionWrites, 0, reason: '不能退化成 upsertSection + N 次 upsertItem');
    expect(repo.itemWrites, 0, reason: '同上');
    final got = await sections();
    expect(got.map((e) => e.title), ['采购']);
    expect(await sectionIdOf('i1'), got.single.id);
    expect(await sectionIdOf('i2'), got.single.id);
    expect(await sectionIdOf('i3'), isNull, reason: '第三条没选中');
    expect(find.byKey(const ValueKey('select_i1')), findsNothing,
        reason: '写完退出选择态，勾选靶要收回去');
  });

  testWidgets('TC-UI-321 一条都没选中 ⇒ ⋯ 菜单那条是死的（无弹层、无提示、零写入）', (tester) async {
    await pump(tester);

    await openMoreMenu(tester);
    expect(find.text('用所选项目新建分区'), findsOneWidget, reason: '入口要在，但要不可点');
    await tester.tap(find.text('用所选项目新建分区'));
    await tester.pumpAndSettle();

    // 置灰的证据：既没弹层、也没走「先选中」提示那条通路（那说明它其实可点）。
    expect(find.byKey(const ValueKey('new_section_name')), findsNothing);
    expect(find.text('先长按选中要归入分区的提醒'), findsNothing);
    expect(repo.createWithTasks, 0);
    expect(repo.sectionWrites, 0);
    expect(await sections(), isEmpty);
  });

  testWidgets('TC-UI-321 macOS 菜单 ⌃⌘N：未选中时给可见提示且不写数据（#537 不变量：壳不判选中）', (tester) async {
    await pump(tester);

    commands.value = LifeMenuAction.createSectionFromSelection;
    await tester.pumpAndSettle();

    expect(find.text('先长按选中要归入分区的提醒'), findsOneWidget,
        reason: '静默 no-op 等于菜单坏了');
    expect(repo.createWithTasks, 0);
    expect(await sections(), isEmpty);
    expect(commands.value, isNull, reason: '命令消费后要清回 null（防重复执行）');
  });

  testWidgets('TC-UI-321 「取消选择」收回勾选靶且不写数据', (tester) async {
    await pump(tester);
    await tester.longPress(find.byKey(const ValueKey('row_long_press_i1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('select_i1')), findsOneWidget);

    await openMoreMenu(tester);
    await tester.tap(find.text('取消选择'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('select_i1')), findsNothing);
    expect(repo.createWithTasks, 0);
    expect(await sections(), isEmpty);
  });
}
