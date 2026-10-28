import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_test/flutter_test.dart';

/// parity#166：Apple 在父行显示子任务进度（`1/2`）。
///
/// 之前行内只有标题 + 列表名/日期/旗标，看不到有没有子任务、做到哪一步，
/// TC-UI-114 却标着「已自动化」。
void main() {
  ReminderItem item() => const ReminderItem(
    id: 'r1',
    listId: 'list.personal',
    title: '搬家',
    dueAt: null,
  );

  Future<void> pump(
    WidgetTester tester, {
    int done = 0,
    int total = 0,
  }) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: ReminderRow(
          item: item(),
          listName: '个人',
          subtaskDone: done,
          subtaskTotal: total,
          onToggleCompleted: () {},
        ),
      ),
    );
  }

  testWidgets('有子任务时行内出现 1/2 进度', (tester) async {
    await pump(tester, done: 1, total: 2);
    expect(find.textContaining('1/2'), findsOneWidget);
  });

  testWidgets('全部完成显示 2/2', (tester) async {
    await pump(tester, done: 2, total: 2);
    expect(find.textContaining('2/2'), findsOneWidget);
  });

  testWidgets('没有子任务时不出现进度', (tester) async {
    await pump(tester);
    expect(find.textContaining('/'), findsNothing);
  });
}
