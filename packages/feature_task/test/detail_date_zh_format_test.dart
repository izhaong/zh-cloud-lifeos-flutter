// #483 / 矩阵 A2 / TC-UI-112：
// 详情「日期与时间」值必须是中文自然格式（含星期），不再用 ISO「2026-10-29」。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

Future<void> _pump(WidgetTester tester, DateTime dueAt) async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(
    const ReminderList(id: 'list.t', title: '测试', colorArgb: 0xFF007AFF),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: lifeTestHost(
        ReminderDetailPane(
          item: ReminderItem(
            id: 'r1',
            listId: 'list.t',
            title: '日期格式',
            dueAt: dueAt,
          ),
          onSaved: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('定时项：日期行显示「2026年10月29日 星期四 09:00」（#483）', (tester) async {
    await _pump(tester, DateTime(2026, 10, 29, 9));

    expect(find.text('2026年10月29日 星期四 09:00'), findsOneWidget);
    expect(
      find.textContaining('2026-10-29'),
      findsNothing,
      reason: '详情面板不再使用 ISO 破折号格式',
    );
  });

  testWidgets('全天项：只显示「2026年10月25日 星期日」，不带时分（#483）', (tester) async {
    await _pump(tester, DateTime(2026, 10, 25));

    expect(find.text('2026年10月25日 星期日'), findsOneWidget);
    expect(find.textContaining('2026-10-25'), findsNothing);
  });
}
