import 'package:flutter/material.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #245：智能视图里新建提醒的落点。
///
/// Apple：智能列表里新建落到账户的 **Default List**；此前客户端写死
/// `list.personal`，既无视设置，又在该列表不存在时生成不可见的孤儿条目。
void main() {
  group('resolveSmartCreateListId', () {
    const work = ReminderList(id: 'list.work', title: '工作');
    const personal = ReminderList(id: 'list.personal', title: '个人');
    const smart = ReminderList(id: 'smart.today', title: '今天', isSmart: true);

    test('默认列表命中 → 用它', () {
      expect(
        resolveSmartCreateListId(
          lists: const [personal, work, smart],
          preferredId: 'list.work',
        ),
        'list.work',
      );
    });

    test('默认列表指向已删列表 → 回退第一个自有列表', () {
      expect(
        resolveSmartCreateListId(
          lists: const [personal, work],
          preferredId: 'list.gone',
        ),
        'list.personal',
      );
    });

    test('未设置默认列表 → 第一个自有列表（跳过智能列表）', () {
      expect(
        resolveSmartCreateListId(
          lists: const [smart, work, personal],
          preferredId: null,
        ),
        'list.work',
      );
    });

    test('没有任何自有列表 → 旧行为兜底（不抛）', () {
      expect(
        resolveSmartCreateListId(
          lists: const [smart],
          preferredId: 'list.work',
        ),
        'list.personal',
      );
    });
  });

  testWidgets('从「今天」新建 → 落在设置的默认列表（不是 list.personal）',
      (tester) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '个人'));
    final prefRepo = InMemoryTaskPreferenceRepository();
    await prefRepo.savePreference(
      const TaskPreference(defaultListId: 'list.work'),
    );

    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          taskPreferenceRepositoryProvider.overrideWithValue(prefRepo),
        ],
        child: const MaterialApp(
          home: TaskScaffold(openListId: 'smart.today'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新提醒事项'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('draft_field')), '买牛奶');
    await tester.tap(find.byKey(const ValueKey('draft_submit')));
    await tester.pumpAndSettle();

    final inWork = await repo.watchItems(listId: 'list.work').first;
    final inPersonal = await repo.watchItems(listId: 'list.personal').first;
    expect(
      inWork.map((e) => e.title),
      contains('买牛奶'),
      reason: '默认列表是「工作」，从「今天」新建就该落这里',
    );
    expect(inPersonal, isEmpty, reason: '不得再写死 list.personal');
    expect(
      inWork.first.dueAt,
      isNotNull,
      reason: '「今天」视图新建仍要带 dueAt，否则条目在视图里不可见',
    );
  });
}
