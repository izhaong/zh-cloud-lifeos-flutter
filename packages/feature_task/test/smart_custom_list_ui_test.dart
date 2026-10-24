import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TC-UI-116 自定义智能列表：建条件（标签=工作 且 旗标）→ 出现在智能列表区
/// → 命中集正确。首期条件维度：标签 + 旗标（SmartListFilter）。
class _Host extends StatefulWidget {
  const _Host({required this.repo});

  final ReminderRepository repo;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? _openListId = 'smart.today';

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(widget.repo),
      ],
      child: MaterialApp(
        home: TaskScaffold(
          openListId: _openListId,
          onOpenList: (id) => setState(() => _openListId = id),
        ),
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required ReminderRepository repo,
}) async {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  await tester.pumpWidget(_Host(repo: repo));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('TC-UI-116 自定义智能列表出现在侧栏智能区且命中集正确',
      (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    // 条件：标签=工作 且 旗标
    await repo.upsertList(
      const ReminderList(
        id: 'smart.custom.workflag',
        title: '工作旗标',
        isSmart: true,
        smartFilter: SmartListFilter(tagEquals: '工作', flaggedOnly: true),
      ),
    );
    await repo.upsertList(
      const ReminderList(id: 'list.w', title: '工作列表'),
    );
    await repo.upsertItem(
      const ReminderItem(
        id: 'hit',
        listId: 'list.w',
        title: '命中条目',
        isFlagged: true,
        tags: ['工作'],
      ),
    );
    await repo.upsertItem(
      const ReminderItem(
        id: 'miss',
        listId: 'list.w',
        title: '缺旗标',
        tags: ['工作'],
      ),
    );

    await _pump(tester, size: const Size(1366, 1024), repo: repo);

    // 侧栏智能区出现自定义卡
    expect(find.text('工作旗标'), findsOneWidget);

    // 点自定义智能卡 → 主区命中集只含 hit
    await tester.tap(find.text('工作旗标'));
    await tester.pumpAndSettle();

    expect(find.text('命中条目'), findsOneWidget);
    expect(find.text('缺旗标'), findsNothing);
  });

  testWidgets('TC-UI-116 无条件自定义智能列表 = 全部未完成（基线语义）',
      (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(
        id: 'smart.custom.all',
        title: '我的全部',
        isSmart: true,
        smartFilter: SmartListFilter(),
      ),
    );
    await repo.upsertList(const ReminderList(id: 'list.w', title: '工作'));
    await repo.upsertItem(
      const ReminderItem(id: 'a', listId: 'list.w', title: '未完成A'),
    );
    await repo.upsertItem(
      const ReminderItem(
        id: 'b',
        listId: 'list.w',
        title: '已完成B',
        isCompleted: true,
      ),
    );

    await _pump(tester, size: const Size(1366, 1024), repo: repo);
    await tester.tap(find.text('我的全部'));
    await tester.pumpAndSettle();

    expect(find.text('未完成A'), findsOneWidget);
    expect(find.text('已完成B'), findsNothing); // 已完成不进智能列表
  });

  testWidgets('TC-UI-116 删除自定义智能列表后 provider → 空集不崩（cursor PR#15）',
      (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(
        id: 'smart.custom.gone',
        title: '将被删',
        isSmart: true,
        smartFilter: SmartListFilter(),
      ),
    );
    await repo.upsertList(const ReminderList(id: 'list.w', title: '工作'));
    await repo.upsertItem(
      const ReminderItem(id: 'a', listId: 'list.w', title: '条目A'),
    );

    await _pump(tester, size: const Size(1366, 1024), repo: repo);
    await tester.tap(find.text('将被删'));
    await tester.pumpAndSettle();
    expect(find.text('条目A'), findsOneWidget); // 删除前命中

    await repo.deleteList('smart.custom.gone');
    await tester.pumpAndSettle();

    expect(find.text('条目A'), findsNothing, reason: '列表删除后命中集须为空');
    expect(tester.takeException(), isNull);
  });

  testWidgets('TC-UI-116 双流 dispose：订阅两周期无泄漏（Stream.multi onCancel）',
      (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(
        id: 'smart.custom.dispose',
        title: '生命周期',
        isSmart: true,
        smartFilter: SmartListFilter(),
      ),
    );
    await repo.upsertList(const ReminderList(id: 'list.w', title: 'W'));

    final container = ProviderContainer(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    for (var cycle = 0; cycle < 2; cycle++) {
      final sub = container.listen(
        filteredItemsForListProvider('smart.custom.dispose'),
        (_, _) {},
      );
      await tester.runAsync(() =>
          Future<void>.delayed(const Duration(milliseconds: 30)));
      expect(sub.read().hasValue, isTrue);
      sub.close(); // 触发 Stream.multi onCancel → 内层订阅取消
      await tester.runAsync(() =>
          Future<void>.delayed(const Duration(milliseconds: 30)));
    }

    // close 后再写数据不抛（onCancel 已清理）
    await repo.upsertItem(
      const ReminderItem(id: 'late', listId: 'list.w', title: '迟到条目'),
    );
    await tester.runAsync(() =>
        Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(tester.takeException(), isNull);
  });
}
