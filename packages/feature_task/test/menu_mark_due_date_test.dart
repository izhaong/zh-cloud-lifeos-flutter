// #537 第 7 刀：macOS「编辑 → 将截止日期标记为…」。
//
// 四档（上午/下午/今晚/今天）与时分一律复用今天视图拖档那一份实现
// （`_sectionTime` + `_onSectionDrop`），菜单只负责选档，不定义第二套
// 「今晚是几点」。「已过期」在拖档里是**不改日期**的语义，所以不做成菜单项。
//
// 断言盯三点：① 落库的是那一档的时刻（用固定时钟量，不跟真实时间较劲）；
// ② 取消不动数据；③ 没选中时给可见提示，不是静默 no-op。
import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

final _clock = DateTime(2026, 11, 2, 10, 15);
final _today = DateTime(2026, 11, 2);

Future<ValueNotifier<LifeMenuAction?>> _pump(
  WidgetTester tester,
  InMemoryReminderRepository repo,
) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final commands = ValueNotifier<LifeMenuAction?>(null);
  addTearDown(commands.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        lifeMenuCommandsProvider.overrideWithValue(commands),
        clockProvider.overrideWithValue(() => _clock),
      ],
      child: lifeTestHost(const TaskScaffold(openListId: 'list.work')),
    ),
  );
  await tester.pumpAndSettle();
  return commands;
}

Future<InMemoryReminderRepository> _repo() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  await repo.upsertItem(const ReminderItem(
    id: 'a',
    listId: 'list.work',
    title: '交月报',
    sortOrder: 0,
  ));
  await repo.upsertItem(const ReminderItem(
    id: 'b',
    listId: 'list.work',
    title: '另一条',
    dueAt: null,
    sortOrder: 1,
  ));
  return repo;
}

Future<DateTime?> _dueOf(ReminderRepository repo, String id) async {
  final items = await repo.watchItems().first;
  return items.firstWhere((e) => e.id == id).dueAt;
}

void main() {
  testWidgets('#537 标记「今晚」= 复用拖档那一份的 20:00', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    await tester.tap(find.text('交月报'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.markDueDate;
    await tester.pumpAndSettle();
    expect(commands.value, isNull, reason: '命令消费后必须清空');

    expect(find.byKey(const ValueKey('mark_due_date_上午')), findsOneWidget);
    expect(find.byKey(const ValueKey('mark_due_date_今晚')), findsOneWidget);
    expect(find.text('已过期'), findsNothing, reason: '拖档里它是“不改日期”，不是档位');

    await tester.tap(find.byKey(const ValueKey('mark_due_date_今晚')));
    await tester.pumpAndSettle();

    expect(await _dueOf(repo, 'a'), DateTime(_today.year, _today.month, _today.day, 20));
    expect(await _dueOf(repo, 'b'), isNull, reason: '只动选中的那条');
  });

  testWidgets('#537 标记「今天」= 全天（00:00），与拖档口径逐字节一致',
      (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    await tester.tap(find.text('另一条'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.markDueDate;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mark_due_date_今天')));
    await tester.pumpAndSettle();

    expect(await _dueOf(repo, 'b'), _today);
    expect((await _dueOf(repo, 'b'))?.hour, 0, reason: '今天档是全天而不是当前时刻');
  });

  testWidgets('#537 取消不改日期', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    await tester.tap(find.text('交月报'));
    await tester.pumpAndSettle();

    commands.value = LifeMenuAction.markDueDate;
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(await _dueOf(repo, 'a'), isNull);
  });

  testWidgets('#537 没选中条目时给可见提示，不是静默 no-op', (tester) async {
    final repo = await _repo();
    final commands = await _pump(tester, repo);

    commands.value = LifeMenuAction.markDueDate;
    await tester.pumpAndSettle();

    expect(find.text('先选中一条提醒事项'), findsOneWidget);
    expect(find.byKey(const ValueKey('mark_due_date_今晚')), findsNothing);
    expect(await _dueOf(repo, 'a'), isNull);
    expect(await _dueOf(repo, 'b'), isNull);
  });
}
