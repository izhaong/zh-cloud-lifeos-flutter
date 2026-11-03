// #576：编辑 → 替换…——对当前选中条目的标题/备注做精确子串替换并落库。
import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

void main() {
  testWidgets('替换当前选中条目的标题与备注（#576）', (tester) async {
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
    await repo.upsertItem(const ReminderItem(
      id: 'i1',
      listId: 'list.a',
      title: '买牛奶 牛奶',
      notes: '牛奶备注',
    ));

    final commands = ValueNotifier<LifeMenuAction?>(null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          lifeMenuCommandsProvider.overrideWithValue(commands),
        ],
        child: lifeTestHost(
          const TaskScaffold(openListId: 'list.a', selectedItemId: 'i1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.replaceText;
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('replace_find')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('replace_find')), '牛奶');
    await tester.enterText(find.byKey(const ValueKey('replace_with')), '咖啡');
    await tester.tap(find.byKey(const ValueKey('replace_submit')));
    await tester.pumpAndSettle();

    final item = (await repo.watchItems().first)
        .firstWhere((e) => e.id == 'i1');
    expect(item.title, '买咖啡 咖啡');
    expect(item.notes, '咖啡备注');
  });

  testWidgets('无选中条目时给可见提示且不崩溃（#576）', (tester) async {
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
    final commands = ValueNotifier<LifeMenuAction?>(null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          lifeMenuCommandsProvider.overrideWithValue(commands),
        ],
        child: lifeTestHost(const TaskScaffold(openListId: 'list.a')),
      ),
    );
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.replaceText;
    await tester.pumpAndSettle();
    expect(find.text('先选中一条提醒事项'), findsOneWidget);
  });
}
