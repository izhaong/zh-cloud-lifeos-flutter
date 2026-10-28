import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

/// parity#161：行内旗标切换后，侧栏「旗标」卡的计数必须立刻更新
/// （此前要整页重载才变）。
void main() {
  testWidgets('旗标一条后，侧栏旗标卡计数立刻变 1', (tester) async {
    final repo = InMemoryReminderRepository();
    await repo.upsertItem(
      const ReminderItem(id: 'r1', listId: 'list.personal', title: '甲'),
    );
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1366, 1024)
      ..devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(
          const TaskScaffold(openListId: 'smart.today'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder countIn(String cardId) => find.descendant(
      of: find.byKey(ValueKey('smart_card_$cardId')),
      matching: find.byType(Text),
    );

    // 仓库自带种子数据，基线按当前读数取，不写死
    int flaggedCount() {
      final texts = tester
          .widgetList<Text>(countIn('smart.flagged'))
          .map((t) => t.data)
          .whereType<String>();
      return int.parse(texts.firstWhere((t) => int.tryParse(t) != null));
    }

    final baseline = flaggedCount();

    await repo.toggleFlagged('r1');
    await tester.pumpAndSettle();

    expect(
      flaggedCount(),
      baseline + 1,
      reason: '旗标切换后计数必须立即 +1，不需重载',
    );

    await repo.toggleFlagged('r1');
    await tester.pumpAndSettle();
    expect(flaggedCount(), baseline, reason: '取消旗标后应回到基线');
  });
}
