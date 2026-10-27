import 'package:cupertino_ui/cupertino_ui.dart' as cui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TC-UI-120 持久半边：设置弹层四档写本地偏好、重开读回、默认列表可选可清、
/// 「还原」写回契约默认（flutter#124 卡 4）。
Future<void> _pump(
  WidgetTester tester, {
  required ReminderRepository repo,
  required TaskPreferenceRepository prefs,
}) async {
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = const Size(1366, 1024)
    ..devicePixelRatio = 1.0;
  // 先卸载上一轮 ProviderScope：同类型元素被复用时 Riverpod 容器与状态不会重建，
  // 「重开弹层读回」就测成了内存态而不是持久化。
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        taskPreferenceRepositoryProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        home: TaskScaffold(openListId: 'smart.today'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('sidebar_settings')));
  await tester.pumpAndSettle();
}

bool _switchValue(WidgetTester tester, String key) => tester
    .widget<cui.CupertinoSwitch>(find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(cui.CupertinoSwitch),
    ))
    .value;

Future<TaskPreference> _saved(TaskPreferenceRepository prefs) =>
    prefs.watchPreference().first;

void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<ReminderRepository> seededRepo() async {
    final repo = InMemoryReminderRepository();
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '个人'));
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
    return repo;
  }

  testWidgets('TC-UI-120 三档切换写进偏好仓库（不再是 setState 会话级）',
      (tester) async {
    final prefs = InMemoryTaskPreferenceRepository();
    await _pump(tester, repo: await seededRepo(), prefs: prefs);

    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('settings_all_day_notify')),
        matching: find.byType(cui.CupertinoSwitch)));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('settings_mark_complete')),
        matching: find.byType(cui.CupertinoSwitch)));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('settings_suggest_lists')),
        matching: find.byType(cui.CupertinoSwitch)));
    await tester.pumpAndSettle();

    final saved = await _saved(prefs);
    expect(saved.allDayNotify, isFalse);
    expect(saved.markComplete, isTrue);
    expect(saved.suggestLists, isFalse);
  });

  testWidgets('TC-UI-120 重开弹层读回已存值（跨会话持久）', (tester) async {
    final repo = await seededRepo();
    final prefs = InMemoryTaskPreferenceRepository();
    await prefs.savePreference(
        const TaskPreference(allDayNotify: false, markComplete: true));

    await _pump(tester, repo: repo, prefs: prefs);

    expect(_switchValue(tester, 'settings_all_day_notify'), isFalse);
    expect(_switchValue(tester, 'settings_mark_complete'), isTrue);
    expect(_switchValue(tester, 'settings_suggest_lists'), isTrue,
        reason: '没改过的档位保持默认开');

    // 关掉再开：值仍在（读的是仓库，不是 State 字段）
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    await _pump(tester, repo: repo, prefs: prefs);
    expect(_switchValue(tester, 'settings_mark_complete'), isTrue);
  });

  testWidgets('TC-UI-120 默认列表可选、可置回「无」', (tester) async {
    final repo = await seededRepo();
    final prefs = InMemoryTaskPreferenceRepository();
    await _pump(tester, repo: repo, prefs: prefs);

    await tester.tap(find.byKey(const ValueKey('settings_default_list')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('default_list_none')), findsOneWidget);
    expect(find.byKey(const ValueKey('default_list_list.work')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('default_list_list.work')));
    await tester.pumpAndSettle();
    expect((await _saved(prefs)).defaultListId, 'list.work');
    expect(find.text('工作'), findsWidgets, reason: '行尾要显示当前默认列表名');

    await tester.tap(find.byKey(const ValueKey('settings_default_list')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('default_list_none')));
    await tester.pumpAndSettle();
    expect((await _saved(prefs)).defaultListId, isNull);
  });

  testWidgets('TC-UI-120「还原」写回契约默认（含默认列表清空）', (tester) async {
    final repo = await seededRepo();
    final prefs = InMemoryTaskPreferenceRepository();
    await prefs.savePreference(const TaskPreference(
        defaultListId: 'list.work',
        allDayNotify: false,
        markComplete: true,
        suggestLists: false));

    await _pump(tester, repo: repo, prefs: prefs);
    await tester.tap(find.byKey(const ValueKey('settings_reset')));
    await tester.pumpAndSettle();

    final back = await _saved(prefs);
    expect(back.defaultListId, isNull);
    expect(back.allDayNotify, isTrue);
    expect(back.markComplete, isFalse);
    expect(back.suggestLists, isTrue);
    expect(_switchValue(tester, 'settings_all_day_notify'), isTrue,
        reason: '还原要当场反映在弹层上，不能等重开');
  });
}
