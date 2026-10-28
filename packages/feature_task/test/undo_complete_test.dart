import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-UI-122：完成一条后可撤销。重做不做。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('TC-UI-122 完成后撤销恢复未完成', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '甲'));
    await repo.upsertItem(const ReminderItem(
      id: 'n1',
      listId: 'list.a',
      title: '买菜',
    ));

    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(375, 812)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: TaskScaffold(openListId: 'list.a'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.circle));
    await tester.pumpAndSettle();

    final done = await repo.watchItems(listId: 'list.a').first;
    expect(done.single.isCompleted, isTrue);
    expect(find.byKey(const ValueKey('undo_complete')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('undo_complete')));
    await tester.pumpAndSettle();

    final restored = await repo.watchItems(listId: 'list.a').first;
    expect(restored.single.isCompleted, isFalse);
    expect(find.text('买菜'), findsOneWidget);
    expect(find.byKey(const ValueKey('undo_complete')), findsNothing);
  });
}
