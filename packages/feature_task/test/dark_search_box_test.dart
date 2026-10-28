import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

/// parity#196：暗色档顶栏搜索框必须是深灰底，不能写死白底胶囊。
void main() {
  testWidgets('暗色下 toolbar_search 背景与描边跟随系统', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1366, 1024)
      ..devicePixelRatio = 1.0;
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(tester.binding.platformDispatcher.clearPlatformBrightnessTestValue);

    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '列表A'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(const TaskScaffold(openListId: 'list.a')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final field = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('toolbar_search')),
    );
    final color = (field.decoration as BoxDecoration).color!;
    final value = color.toARGB32();
    expect(value, isNot(0xFFFFFFFF), reason: '暗色下不该是纯白底');
    // 亮度足够低（systemBackground 暗色 = #000000）
    expect(((value >> 16) & 0xFF), lessThan(80));
  });
}
