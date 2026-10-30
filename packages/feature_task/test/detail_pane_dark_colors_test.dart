// #489 / 矩阵行 28（外观跟随系统）：
// 暗色档下详情第三栏的分组卡片必须是深色底、标签必须是浅色字；
// 修复前卡片底写死 CupertinoColors.white、标签继承默认白字 → 白字白底不可读。
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

final _item = ReminderItem(
  id: 'r1',
  listId: 'list.t',
  title: '暗色详情',
  dueAt: DateTime(2026, 10, 29, 9),
);

Future<void> _pump(
  WidgetTester tester,
  Brightness brightness,
) async {
  tester.binding.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(
    tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
  );
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = const Size(900, 1300)
    ..devicePixelRatio = 1.0;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(
    const ReminderList(id: 'list.t', title: '测试', colorArgb: 0xFF007AFF),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: lifeTestHost(
        ReminderDetailPane(item: _item, onSaved: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color _containerColor(WidgetTester tester, String key) {
  final box = tester.widget<Container>(find.byKey(ValueKey(key)));
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('暗色档：详情卡片是深色底，标题/备注是浅色字（#489）', (tester) async {
    await _pump(tester, Brightness.dark);

    final titleCard = _containerColor(tester, 'detail_card_title').toARGB32();
    final rowsCard = _containerColor(tester, 'detail_card_rows').toARGB32();
    expect(titleCard, 0xFF1C1C1E, reason: '暗色卡片底应为 #1C1C1E');
    expect(rowsCard, 0xFF1C1C1E, reason: '字段分组卡也应是深色底');

    final title = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('detail_title')),
    );
    final titleColor = title.style!.color!.toARGB32();
    expect(titleColor, 0xFFFFFFFF, reason: '暗色标题是浅色字');
    expect(titleColor, isNot(titleCard), reason: '白字不能压在白底上');

    final notes = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('detail_notes')),
    );
    expect(notes.style!.color!.toARGB32(), 0xFFFFFFFF);
  });

  testWidgets('亮色档对照：卡片白底、标题黑字（防恒真）', (tester) async {
    await _pump(tester, Brightness.light);

    expect(_containerColor(tester, 'detail_card_title').toARGB32(), 0xFFFFFFFF);
    final title = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('detail_title')),
    );
    expect(title.style!.color!.toARGB32(), 0xFF000000);
  });
}
