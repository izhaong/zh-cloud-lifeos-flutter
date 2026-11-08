// #699：同 id 外部写入旗标后，详情面板本地开关必须回刷。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

bool _switchValue(WidgetTester tester) {
  final sw = tester.allWidgets.firstWhere(
    (w) => w.runtimeType.toString() == 'CupertinoSwitch',
  );
  // cupertino_ui / flutter 的 CupertinoSwitch 都有 value
  return (sw as dynamic).value as bool;
}

void main() {
  testWidgets('#699 同 id 旗标变更 → 详情开关同步', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    var item = const ReminderItem(
      id: 'r1',
      listId: 'list.a',
      title: '待旗标',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: ReminderDetailPane(item: item, onSaved: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('标记'), findsOneWidget);
    expect(_switchValue(tester), isFalse);

    item = item.copyWith(isFlagged: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: ReminderDetailPane(item: item, onSaved: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_switchValue(tester), isTrue, reason: '同 id 外部旗标变更后详情开关须同步');
  });
}
