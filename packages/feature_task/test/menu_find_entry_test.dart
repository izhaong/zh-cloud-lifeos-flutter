// #537 第 6 刀：macOS「编辑 → 查找…」。
//
// 键盘侧 ⌘F 早就把搜索框聚焦了（feature_task 的 `TaskShortcuts` 把 meta+F 绑成
// `requestFocusSearch`，`_onShortcut` 比对 `focusSearchTicket` 后 requestFocus）。
// 本刀只补**菜单入口**：命令 → 同一个票据 → 同一个焦点请求，不新写第二套聚焦，
// 也不新写第二套过滤（搜索词一律走既有 `searchQueryProvider`）。
//
// 另外这里顺手修了一处真缺口：紧凑档的 `compact_search` 原先没挂焦点节点，
// 「查找…」在窄宽下会打不到任何输入框。两档渲染互斥（`isPane` 二选一），
// 所以共用同一个 `_searchFocus` 节点是安全的——下面第 3 例守的就是它。
import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

Future<ValueNotifier<LifeMenuAction?>> _pump(
  WidgetTester tester,
  ReminderRepository repo, {
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final commands = ValueNotifier<LifeMenuAction?>(null);
  addTearDown(commands.dispose);
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
  return commands;
}

/// 种子：两条标题可区分的条目，才能用「某条还在不在」量过滤是否真跑通。
Future<InMemoryReminderRepository> _repo() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  await repo.upsertItem(const ReminderItem(
    id: 'a',
    listId: 'list.work',
    title: '买牛奶',
    sortOrder: 0,
  ));
  await repo.upsertItem(const ReminderItem(
    id: 'b',
    listId: 'list.work',
    title: '写周报',
    sortOrder: 1,
  ));
  return repo;
}

bool _focused(WidgetTester tester, Key fieldKey) {
  final editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(fieldKey),
      matching: find.byType(EditableText),
    ),
  );
  return editable.focusNode.hasFocus;
}

const _toolbar = ValueKey<String>('toolbar_search');
const _compact = ValueKey<String>('compact_search');

void main() {
  testWidgets('#537 宽屏：菜单「查找…」把焦点交给工具栏搜索框', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    expect(find.byKey(_toolbar), findsOneWidget);
    expect(_focused(tester, _toolbar), isFalse, reason: '默认不该抢焦点');

    commands.value = LifeMenuAction.findReminder;
    await tester.pumpAndSettle();

    expect(commands.value, isNull, reason: '命令消费后必须清空');
    expect(_focused(tester, _toolbar), isTrue);
  });

  testWidgets('#537 聚焦后打字走既有过滤，不是第二套搜索', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    commands.value = LifeMenuAction.findReminder;
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(_toolbar), '周报');
    await tester.pumpAndSettle();

    expect(find.text('写周报'), findsOneWidget);
    expect(find.text('买牛奶'), findsNothing, reason: '过滤由 searchQueryProvider 干');
    // 数据一律没动（搜索是视图态）
    expect((await repo.watchItems().first).length, 2);
  });

  testWidgets('#537 紧凑档：「查找…」聚焦的是屏幕上那个搜索框', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo, size: const Size(390, 844));

    expect(find.byKey(_compact), findsOneWidget);
    expect(find.byKey(_toolbar), findsNothing, reason: '两档互斥');
    expect(_focused(tester, _compact), isFalse);

    commands.value = LifeMenuAction.findReminder;
    await tester.pumpAndSettle();

    expect(_focused(tester, _compact), isTrue,
        reason: 'compact_search 不挂焦点节点时这里会红——窄宽下打不到输入框');
  });

  testWidgets('#537 连点两次不重复出错，焦点保持在搜索框', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    commands.value = LifeMenuAction.findReminder;
    await tester.pumpAndSettle();
    commands.value = LifeMenuAction.findReminder;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(commands.value, isNull);
    expect(_focused(tester, _toolbar), isTrue);
  });
}
