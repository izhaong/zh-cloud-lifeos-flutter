// #475：计划/紧急视图分区按日期升序排。
// #479 后标签为按日粒度：前天/昨天/今天/明天/后天 + 绝对日期带星期后缀，
// 期望序列随之适配（升序意图不变：10-27=D-2 显示「前天」，最早日期组仍在前）。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 29, 9, 30);

Future<InMemoryReminderRepository> _seed() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
  // 覆盖：已过期(10-27) / 今天(10-29) / 明天(10-30) / 10月31日 / 11月5日
  await repo.upsertItem(ReminderItem(
    id: 'i-overdue', listId: 'list.work', title: '过期项',
    dueAt: DateTime(2026, 10, 27, 15),
  ));
  await repo.upsertItem(ReminderItem(
    id: 'i-today', listId: 'list.work', title: '今天项',
    dueAt: DateTime(2026, 10, 29, 10),
  ));
  await repo.upsertItem(ReminderItem(
    id: 'i-tomorrow', listId: 'list.work', title: '明天项',
    dueAt: DateTime(2026, 10, 30, 10),
  ));
  await repo.upsertItem(ReminderItem(
    id: 'i-oct31', listId: 'list.work', title: '10月31日项',
    dueAt: DateTime(2026, 10, 31, 10),
  ));
  await repo.upsertItem(ReminderItem(
    id: 'i-nov5', listId: 'list.work', title: '11月5日项',
    dueAt: DateTime(2026, 11, 5, 8),
  ));
  return repo;
}

Widget _host(InMemoryReminderRepository repo, String listId) {
  repo.nowProvider = () => _now;
  return ProviderScope(
    overrides: [
      reminderRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => _now),
    ],
    child: MaterialApp(home: TaskScaffold(openListId: listId)),
  );
}

/// 提取渲染文本树中分区头的顺序。
/// 分区头精确匹配：已过期/前天/昨天/今天/明天/后天 / X月Y日[ 周X]，不匹配条目标题。
List<String> _sectionHeaders(WidgetTester tester) {
  final out = <String>[];
  final sectionPattern = RegExp(r'^\d+月\d+日( 周[一二三四五六日])?$');
  void walk(Element e) {
    final w = e.widget;
    if (w is Text) {
      final d = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
      if (d == '已过期' || d == '前天' || d == '昨天' || d == '今天' ||
          d == '明天' || d == '后天' || sectionPattern.hasMatch(d)) {
        out.add(d);
      }
    }
    e.visitChildren(walk);
  }
  walk(tester.binding.rootElement!);
  return out;
}

void main() {
  testWidgets('#475 计划视图分区按日期升序', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(await _seed(), 'smart.scheduled'));
    await tester.pumpAndSettle();

    final texts = _sectionHeaders(tester);
    // 找到分区头（今天/明天/已过期/X月Y日）
    final sections = texts.where((t) =>
        t == '已过期' || t == '前天' || t == '昨天' || t == '今天' ||
            t == '明天' || t == '后天' ||
            (t.contains('月') && t.contains('日'))).toList();

    // 期望顺序（#479 后）：前天 → 今天 → 明天 → 10月31日 周六 → 11月5日 周四
    // 10-31 相对 10-29 是 D+2 → 「后天」（#479 相对词优先于绝对日期）。
    final expected = ['前天', '今天', '明天', '后天', '11月5日 周四'];
    var idx = 0;
    for (final t in sections) {
      if (idx < expected.length && t == expected[idx]) {
        idx++;
      }
    }
    expect(idx, expected.length,
        reason: '分区应按日期升序子序列出现，实际为 $sections');
  });

  testWidgets('#475 紧急视图分区按日期升序', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 紧急视图 = 过期未完成 OR 高优先级；给未来条目设高优先级使其入组
    final repo = await _seed();
    await repo.upsertItem(ReminderItem(
      id: 'i-high-oct31', listId: 'list.work', title: '高优10月31日',
      dueAt: DateTime(2026, 10, 31, 10), priority: 9,
    ));
    await repo.upsertItem(ReminderItem(
      id: 'i-high-nov5', listId: 'list.work', title: '高优11月5日',
      dueAt: DateTime(2026, 11, 5, 8), priority: 9,
    ));

    await tester.pumpWidget(_host(repo, 'smart.urgent'));
    await tester.pumpAndSettle();

    final texts = _sectionHeaders(tester);
    final sections = texts.where((t) =>
        t == '已过期' || t == '前天' || t == '昨天' || t == '今天' ||
            t == '明天' || t == '后天' ||
            (t.contains('月') && t.contains('日'))).toList();

    // 紧急视图含：过期项 + 高优10月31日 + 高优11月5日
    // 前天 → 10月31日 周六 → 11月5日 周四（子序列验证）
    final expected = ['前天', '后天', '11月5日 周四'];
    var idx = 0;
    for (final t in sections) {
      if (idx < expected.length && t == expected[idx]) {
        idx++;
      }
    }
    expect(idx, expected.length,
        reason: '紧急视图分区应按日期升序子序列出现，实际为 $sections');
  });
}
