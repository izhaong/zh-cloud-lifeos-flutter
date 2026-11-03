// #572：文件 → 打印…——当前列表导出 PDF 并交给打印端口。
import 'dart:typed_data';

import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

void main() {
  test('PDF 构建：非空且带 %PDF 头（#572）', () async {
    final bytes = await buildTaskListPdf(
      listTitle: 'Work',
      items: const [
        ReminderItem(id: 'a', listId: 'l', title: 'Buy milk'),
        ReminderItem(
          id: 'b',
          listId: 'l',
          title: 'Meeting',
          dueAt: null,
        ),
      ],
    );
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  testWidgets('菜单「打印…」把当前列表交给打印端口（#572）', (tester) async {
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
    await repo.upsertItem(
      const ReminderItem(id: 'i1', listId: 'list.a', title: '一条提醒'),
    );
    Uint8List? printed;
    String? printedName;
    final commands = ValueNotifier<LifeMenuAction?>(null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          lifeMenuCommandsProvider.overrideWithValue(commands),
          taskPrintPortProvider.overrideWithValue((bytes, name) async {
            printed = bytes;
            printedName = name;
          }),
        ],
        child: lifeTestHost(const TaskScaffold(openListId: 'list.a')),
      ),
    );
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.printList;
    await tester.pumpAndSettle();

    expect(printed, isNotNull, reason: '应把 PDF 交给打印端口');
    expect(printedName, '工作');
    expect(String.fromCharCodes(printed!.take(5)), '%PDF-');
  });
}
