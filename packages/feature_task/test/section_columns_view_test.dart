import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';

/// flutter#602：矩阵行 41「分区·按分区列排」（Apple View ▸ Columns）。
///
/// 断言一律挂本卡自己带的 key，不用全树文案。
/// 反向探针挂在「有分区才分列」这条判断上（`task_scaffold.dart` 的
/// `widget.list.sections.isNotEmpty`）：摘掉它，用例 2 当场红。
Future<ProviderContainer> _pane(
  WidgetTester tester, {
  required ReminderList list,
  required List<ReminderItem> items,
}) async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(list);
  for (final i in items) {
    await repo.upsertItem(i);
  }
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 700,
            child: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return ListContentPane(list: list);
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

const _sectioned = ReminderList(
  id: 'list.trip',
  title: '行程',
  sections: [
    ReminderSection(id: 's1', title: '进行中', sortOrder: 0),
    ReminderSection(id: 's2', title: '收尾', sortOrder: 1),
  ],
);

const _plain = ReminderList(id: 'list.plain', title: '无分区清单');

List<ReminderItem> _items(String listId) => [
  ReminderItem(id: 'i1', listId: listId, title: '订机票', sectionId: 's1'),
  ReminderItem(id: 'i2', listId: listId, title: '订酒店', sectionId: 's1'),
  ReminderItem(id: 'i3', listId: listId, title: '打包', sectionId: 's2'),
];

void main() {
  testWidgets('开关开 + 有分区 ⇒ 每个分区一条横向列，列头带计数', (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(_sectioned);
    for (final i in _items('list.trip')) {
      await repo.upsertItem(i);
    }
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: Builder(
                builder: (context) {
                  container = ProviderScope.containerOf(context);
                  return const ListContentPane(list: _sectioned);
                },
              ),
            ),
          ),
        ),
      ),
    );
    container.read(sectionColumnsProvider.notifier).toggle();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section_columns')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_column_进行中')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_column_收尾')), findsOneWidget);
    // 列头计数 = 该分区条目数（进行中 2 条）
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('section_header_进行中')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('反向探针：清单没有分区时不得出现分列视图（回退列表）', (tester) async {
    final container = await _pane(
      tester,
      list: _plain,
      items: const [ReminderItem(id: 'p1', listId: 'list.plain', title: '买牛奶')],
    );
    container.read(sectionColumnsProvider.notifier).toggle();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section_columns')), findsNothing);
    expect(find.text('买牛奶'), findsOneWidget);
  });

  testWidgets('开关默认关：有分区也仍走原列表视图，不出现横向列', (tester) async {
    await _pane(tester, list: _sectioned, items: _items('list.trip'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section_columns')), findsNothing);
    expect(find.text('订机票'), findsOneWidget);
  });

  testWidgets('视图态写进偏好行的键袋（sectionColumns），不是内存态', (tester) async {
    final prefs = InMemoryTaskPreferenceRepository();
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(_sectioned);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          taskPreferenceRepositoryProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    container.read(sectionColumnsProvider.notifier).toggle();
    await tester.pumpAndSettle();

    final saved = await prefs.watchPreference().first;
    expect(saved.viewOptionBool('sectionColumns'), isTrue);
  });
}
