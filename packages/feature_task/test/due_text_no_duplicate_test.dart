import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_test/flutter_test.dart';

/// parity#205：列表名与日期都是「今天」时，行副标题不能出现「今天 · 今天」。
void main() {
  final now = DateTime.now();
  ReminderItem item() => ReminderItem(
    id: 'r1',
    listId: 'list.a',
    title: '寄快递',
    dueAt: DateTime(now.year, now.month, now.day), // 只有日期
  );

  testWidgets('listName 与日期同词时只出现一次', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: ReminderRow(
          item: item(),
          listName: '今天',
          onToggleCompleted: () {},
        ),
      ),
    );
    expect(find.textContaining('今天 · 今天'), findsNothing);
    expect(find.textContaining('今天'), findsOneWidget);
  });

  testWidgets('列表名不同则保留「列表 · 今天」', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: ReminderRow(
          item: item(),
          listName: '个人',
          onToggleCompleted: () {},
        ),
      ),
    );
    expect(find.textContaining('个人'), findsOneWidget);
    expect(find.textContaining('今天'), findsOneWidget);
  });
}
