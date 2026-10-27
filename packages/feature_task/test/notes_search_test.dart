import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-UI-113：详情保存备注后，工具栏搜索能命中。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('TC-UI-113 备注保存后可被搜索命中', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '甲'));
    await repo.upsertItem(
      const ReminderItem(id: 'n1', listId: 'list.a', title: '交报告'),
    );

    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1366, 1024)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: TaskScaffold(openListId: 'list.a', selectedItemId: 'n1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final notesField = find.byKey(const ValueKey('detail_notes'));
    expect(notesField, findsOneWidget);
    await tester.enterText(notesField, '对齐备注文案');
    await tester.tap(find.byKey(const ValueKey('detail_save')));
    await tester.pumpAndSettle();

    final saved = await repo.watchItems(listId: 'list.a').first;
    expect(saved.single.notes, '对齐备注文案');

    await tester.enterText(
      find.byKey(const ValueKey('toolbar_search')),
      '对齐备注文案',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('row_flag_n1')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('toolbar_search')),
      '无关词xyz',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('row_flag_n1')), findsNothing);
    expect(find.text('无匹配结果'), findsOneWidget);
  });
}
