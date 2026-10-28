import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TC-UI-308/309/304 持久半边：视图态（显示已完成、排序、分区折叠、侧栏显隐）
/// 落进本地偏好行，重开/重启后读回（flutter#124 卡 4b）。
void main() {
  late InMemoryTaskPreferenceRepository prefs;

  /// #256：按列表的本地视图记忆走 SharedPreferences（组合根同款注入）
  late SharedPreferences viewPrefs;

  Future<void> pump(
    WidgetTester tester, {
    required ReminderRepository repo,
    String openListId = 'list.work',
    Size size = const Size(1366, 1024),
  }) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    // 先卸载上一轮的 ProviderScope：pumpWidget 复用同类型元素时，
    // Riverpod 容器与 Notifier 状态会原样留着——那样「重开读回」测的是内存态而不是持久化，
    // 摘掉持久化写入探针也不会红（真机上是冷启动，必须真的重建一次）。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          taskPreferenceRepositoryProvider.overrideWithValue(prefs),
          taskViewPrefsProvider.overrideWithValue(viewPrefs),
        ],
        child: MaterialApp(
          home: TaskScaffold(openListId: openListId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    viewPrefs = await SharedPreferences.getInstance();
    prefs = InMemoryTaskPreferenceRepository();
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// 两条：香蕉未完成、苹果已完成（同 list.work）。
  Future<ReminderRepository> seedTwo() async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
    await repo.upsertItem(
        const ReminderItem(id: 'i1', listId: 'list.work', title: '香蕉'));
    await repo.upsertItem(const ReminderItem(
        id: 'i2', listId: 'list.work', title: '苹果', isCompleted: true));
    return repo;
  }

  /// 三条按 dueAt 分桶：今天 / 明天 / 无日期。
  Future<ReminderRepository> seedBuckets() async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
    final now = DateTime.now();
    await repo.upsertItem(ReminderItem(
        id: 't1', listId: 'list.work', title: '今天的事', dueAt: now));
    await repo.upsertItem(ReminderItem(
        id: 't2',
        listId: 'list.work',
        title: '明天的事',
        dueAt: now.add(const Duration(days: 1))));
    await repo.upsertItem(
        const ReminderItem(id: 't3', listId: 'list.work', title: '无日期事'));
    return repo;
  }

  testWidgets('TC-UI-309 分区折叠写进偏好并在重开后保持', (tester) async {
    final repo = await seedBuckets();
    await pump(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('section_今天')));
    await tester.pumpAndSettle();
    expect(find.text('今天的事'), findsNothing, reason: '折叠当场生效');
    expect((await prefs.watchPreference().first).collapsedKeys,
        contains('list.work|今天'),
        reason: '键要带列表前缀，切列表不串味');

    // 重开（新的 ProviderScope = 新的 State，内存态必然丢）
    await pump(tester, repo: repo);
    expect(find.text('今天的事'), findsNothing, reason: '折叠态从偏好行读回');
    expect(find.text('明天的事'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('section_今天')));
    await tester.pumpAndSettle();
    expect(find.text('今天的事'), findsOneWidget, reason: '再点展开');
    expect((await prefs.watchPreference().first).collapsedKeys, isEmpty);
  });

  testWidgets('TC-UI-309 侧栏分组折叠与分区折叠同一条偏好行，键互不撞',
      (tester) async {
    final repo = await seedBuckets();
    await pump(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('section_今天')));
    await tester.pumpAndSettle();
    final keys = (await prefs.watchPreference().first).collapsedKeys;
    expect(keys, ['list.work|今天']);
    expect(keys.any((k) => k.startsWith('group:')), isFalse);
  });

  testWidgets('TC-UI-308 显示已完成持久：重开后已完成项仍可见', (tester) async {
    final repo = await seedTwo();
    await pump(tester, repo: repo);
    expect(find.text('苹果'), findsNothing, reason: 'TC-UI-108 默认仍隐藏');

    await tester.tap(find.byKey(const ValueKey('toggle_show_completed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示已完成').last);
    await tester.pumpAndSettle();
    expect(find.text('苹果'), findsOneWidget);
    expect((await prefs.watchPreference().first).showCompleted, isTrue);

    await pump(tester, repo: repo);
    expect(find.text('苹果'), findsOneWidget, reason: '视图偏好读回，不用每次重开再点');
  });

  testWidgets('TC-UI-308 排序模式持久：切「按标题」后重开仍是那个序',
      (tester) async {
    final repo = await seedTwo();
    await pump(tester, repo: repo);
    await tester.tap(find.byKey(const ValueKey('toggle_show_completed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示已完成').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sort_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按标题'));
    await tester.pumpAndSettle();
    expect((await prefs.watchPreference().first).sortMode, 'title');
    // 标题序：苹果(U+82F9) 排在 香蕉(U+9999) 前；manual 序是 id 升序（香蕉在前）
    expect(tester.getTopLeft(find.text('苹果')).dy,
        lessThan(tester.getTopLeft(find.text('香蕉')).dy),
        reason: '切完当场就是按标题序');

    await pump(tester, repo: repo);
    expect(find.text('苹果'), findsOneWidget);
    expect(tester.getTopLeft(find.text('苹果')).dy,
        lessThan(tester.getTopLeft(find.text('香蕉')).dy),
        reason: '重开后还是按标题序（manual 序下香蕉在前）');
  });

  testWidgets('TC-UI-304 侧栏显隐持久：隐藏后重开仍隐藏', (tester) async {
    final repo = await seedBuckets();
    await pump(tester, repo: repo);

    await tester.tap(find.byKey(const ValueKey('sidebar_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('我的列表'), findsNothing);
    expect((await prefs.watchPreference().first).sidebarVisible, isFalse);

    await pump(tester, repo: repo);
    expect(find.text('我的列表'), findsNothing, reason: '隐藏状态读回');
    expect(find.byKey(const ValueKey('show_sidebar')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('show_sidebar')));
    await tester.pumpAndSettle();
    expect(find.text('我的列表'), findsOneWidget);
    expect((await prefs.watchPreference().first).sidebarVisible, isTrue);
  });

  testWidgets('TC-UI-309「还原默认」清掉视图态：折叠与显示已完成都回默认',
      (tester) async {
    final repo = await seedBuckets();
    await pump(tester, repo: repo);
    await tester.tap(find.byKey(const ValueKey('section_今天')));
    await tester.pumpAndSettle();
    expect((await prefs.watchPreference().first).collapsedKeys, isNotEmpty);

    // 打开设置弹层点还原
    await tester.tap(find.byKey(const ValueKey('sidebar_settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings_reset')));
    await tester.pumpAndSettle();

    final back = await prefs.watchPreference().first;
    expect(back.collapsedKeys, isEmpty);
    expect(back.showCompleted, isFalse);
    expect(back.sortMode, 'manual');
    expect(back.sidebarVisible, isTrue);
  });
}
