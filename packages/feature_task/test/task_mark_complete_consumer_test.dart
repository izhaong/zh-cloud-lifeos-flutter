import 'package:cupertino_ui/cupertino_ui.dart' as cui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';

/// parity#418 面 ①：`markComplete` 原先落库后零消费者（全仓只命中 drift 的列声明
/// 与 codegen 产物）。现在它是「勾掉某父提醒的**最后一个**子任务 ⇒ 父提醒一并标记
/// 完成」的开关；判据全读仓库真值，不看界面文案。
///
/// 面 ②（硬编码 `Text('简体中文')` 的「采购清单语言」行）不在本卡：撤行会撞
/// TC-UI-306「图1 全字段」用例，做成真选择器又要动 Drift schema，已拆新单。
void main() {
  const parent = ReminderItem(id: 'p1', listId: 'list.personal', title: '装修');
  const subA = ReminderItem(
    id: 'sa',
    listId: 'list.personal',
    title: '买油漆',
    parentId: 'p1',
  );
  const subB = ReminderItem(
    id: 'sb',
    listId: 'list.personal',
    title: '请师傅',
    parentId: 'p1',
  );
  const subCDone = ReminderItem(
    id: 'sc',
    listId: 'list.personal',
    title: '量尺寸',
    parentId: 'p1',
    isCompleted: true,
  );

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<InMemoryReminderRepository> seeded({bool withDoneSub = false}) async {
    final repo = InMemoryReminderRepository();
    await repo.upsertList(const ReminderList(id: 'list.personal', title: '个人'));
    await repo.upsertItem(parent);
    await repo.upsertItem(subA);
    await repo.upsertItem(subB);
    if (withDoneSub) {
      await repo.upsertItem(subCDone);
    }
    return repo;
  }

  /// 挂三个「按 id 走真入口 [completeReminder]」的按钮。
  ///
  /// 勾完的 Future 记进 [pending]，测试当场 await——不等 pumpAndSettle 撞运气。
  Future<void> pumpHarness(
    WidgetTester tester, {
    required ReminderRepository repo,
    required TaskPreference pref,
    required List<Future<void>> pending,
  }) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1000, 900)
      ..devicePixelRatio = 1.0;
    final prefs = InMemoryTaskPreferenceRepository();
    await prefs.savePreference(pref);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          taskPreferenceRepositoryProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: _Harness(repo: repo, pending: pending),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> toggle(
    WidgetTester tester,
    String id,
    List<Future<void>> pending,
  ) async {
    final before = pending.length;
    await tester.tap(find.byKey(ValueKey('toggle_$id')));
    await tester.pump();
    expect(pending.length, before + 1, reason: '$id 这次没真走勾选入口');
    await pending.last;
    await tester.pumpAndSettle();
  }

  Future<ReminderItem> itemOf(ReminderRepository repo, String id) async {
    final items = await repo.watchItems(listId: null).first;
    return items.where((e) => e.id == id).first;
  }

  testWidgets('开：勾掉最后一个子任务 ⇒ 父提醒标记完成并带完成时间', (tester) async {
    final repo = await seeded();
    final pending = <Future<void>>[];
    await pumpHarness(
      tester,
      repo: repo,
      pref: const TaskPreference(markComplete: true),
      pending: pending,
    );

    await toggle(tester, 'sa', pending);
    expect(
      (await itemOf(repo, 'p1')).isCompleted,
      isFalse,
      reason: '还剩一个未完成子任务，父提醒不该自己完成',
    );

    await toggle(tester, 'sb', pending);
    final p1 = await itemOf(repo, 'p1');
    expect(p1.isCompleted, isTrue, reason: '最后一个子任务勾掉后父提醒要跟上');
    expect(p1.completedAt, isNotNull, reason: '与行内勾选同一口径，要写完成时间');
  });

  testWidgets('关（契约默认）：勾完全部子任务 ⇒ 父提醒不自己完成', (tester) async {
    final repo = await seeded();
    final pending = <Future<void>>[];
    expect(
      TaskPreference.defaults.markComplete,
      isFalse,
      reason: '默认是关；这条前提变了后面的断言就没意义',
    );
    await pumpHarness(
      tester,
      repo: repo,
      pref: TaskPreference.defaults,
      pending: pending,
    );

    await toggle(tester, 'sa', pending);
    await toggle(tester, 'sb', pending);
    expect(
      (await itemOf(repo, 'p1')).isCompleted,
      isFalse,
      reason: '关掉设置后子任务全完成也不动父提醒——这才叫有消费者',
    );
  });

  testWidgets('开：反手取消一个子任务 ⇒ 子任务回到未完成，父提醒不重复翻动', (tester) async {
    final repo = await seeded();
    final pending = <Future<void>>[];
    await pumpHarness(
      tester,
      repo: repo,
      pref: const TaskPreference(markComplete: true),
      pending: pending,
    );

    await toggle(tester, 'sa', pending);
    await toggle(tester, 'sb', pending);
    expect((await itemOf(repo, 'p1')).isCompleted, isTrue);

    await toggle(tester, 'sb', pending);
    expect(
      (await itemOf(repo, 'sb')).isCompleted,
      isFalse,
      reason: '再勾一次是取消完成',
    );
  });

  testWidgets('开：勾掉子任务后父提醒已完成 ⇒ 不因第二次级联而报错或翻回', (tester) async {
    final repo = await seeded(withDoneSub: true);
    final pending = <Future<void>>[];
    await pumpHarness(
      tester,
      repo: repo,
      pref: const TaskPreference(markComplete: true),
      pending: pending,
    );

    await toggle(tester, 'sa', pending);
    await toggle(tester, 'sb', pending);
    final p1 = await itemOf(repo, 'p1');
    expect(p1.isCompleted, isTrue);
    expect(p1.completedAt, isNotNull, reason: '只记一次完成时间，别被重复写覆盖');
  });
}

/// 只为拿 `WidgetRef` 调真入口 [completeReminder]，本身不是被测对象。
class _Harness extends ConsumerWidget {
  const _Harness({required this.repo, required this.pending});

  final ReminderRepository repo;
  final List<Future<void>> pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> run(String id) async {
      final items = await repo.watchItems(listId: null).first;
      await completeReminder(ref, items.where((e) => e.id == id).first);
    }

    return Column(
      children: [
        for (final id in const ['sa', 'sb', 'p1'])
          cui.CupertinoButton(
            key: ValueKey('toggle_$id'),
            onPressed: () => pending.add(run(id)),
            child: Text(id),
          ),
      ],
    );
  }
}
