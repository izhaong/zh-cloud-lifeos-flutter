import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #258：「建议列表」设置此前只写不读（死开关）。Apple 关掉后不该再推荐。
void main() {
  Future<InMemoryReminderRepository> seed() async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '列表A'));
    return repo;
  }

  Future<void> pump(
    WidgetTester tester,
    InMemoryReminderRepository repo, {
    required bool suggestLists,
    String? openListId = 'list.a',
    Size size = const Size(1366, 1024),
  }) async {
    final prefs = InMemoryTaskPreferenceRepository();
    await prefs.savePreference(
      TaskPreference.defaults.copyWith(suggestLists: suggestLists),
    );
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          taskPreferenceRepositoryProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(home: TaskScaffold(openListId: openListId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('侧栏：开关打开（默认）→ 出现建议列表', (tester) async {
    await pump(tester, await seed(), suggestLists: true);
    expect(find.byKey(const ValueKey('suggested_grocery')), findsOneWidget);
  });

  testWidgets('侧栏：开关关闭 → 建议列表消失（设置真的生效）', (tester) async {
    await pump(tester, await seed(), suggestLists: false);
    expect(find.byKey(const ValueKey('suggested_grocery')), findsNothing);
  });

  testWidgets('首页（compact）：开→有建议卡，关→没有', (tester) async {
    const phone = Size(375, 812);
    await pump(
      tester,
      await seed(),
      suggestLists: true,
      openListId: null,
      size: phone,
    );
    expect(find.byKey(const ValueKey('suggested_grocery_home')), findsOneWidget);

    await pump(
      tester,
      await seed(),
      suggestLists: false,
      openListId: null,
      size: phone,
    );
    expect(find.byKey(const ValueKey('suggested_grocery_home')), findsNothing,
        reason: '首页建议卡同样受开关控制');
  });
}
