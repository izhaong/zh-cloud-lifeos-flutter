// #573：显示 → 列表视图 / 分栏视图。分栏（默认）在 expanded 出第三栏；
// 列表视图只留侧栏 + 列表，选择写进 viewOptionsJson.columnsView。
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

void main() {
  testWidgets('expanded 默认分栏，切列表视图后只剩两栏且偏好落库（#573）', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '工作'));
    await repo.upsertItem(
      const ReminderItem(id: 'i1', listId: 'list.a', title: '一条提醒'),
    );
    final prefs = InMemoryTaskPreferenceRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          taskPreferenceRepositoryProvider.overrideWithValue(prefs),
        ],
        child: lifeTestHost(const TaskScaffold(openListId: 'list.a')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('three_pane')), findsOneWidget);
    expect(find.byKey(const ValueKey('two_pane')), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TaskScaffold)),
    );
    container.read(taskViewModeProvider.notifier).set(false);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('two_pane')), findsOneWidget);
    expect(find.byKey(const ValueKey('three_pane')), findsNothing);
    final saved = await prefs.watchPreference().first;
    expect(saved.viewOptionBool('columnsView', fallback: true), isFalse,
        reason: '列表视图必须写进本地偏好');

    container.read(taskViewModeProvider.notifier).set(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('three_pane')), findsOneWidget);
  });
}
