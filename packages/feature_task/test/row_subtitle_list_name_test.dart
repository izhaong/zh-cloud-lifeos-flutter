import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'support/life_test_app.dart';

/// #89 P1-6 回归锁：行副标题显示**所属列表名**，不是当前视图名。
///
/// 口径（Apple 实测：条目副标题 = 「列表名 今天 05:00」，参考
/// `docs/ui-evidence/2026-10-27-apple-reminders-reference.png`）：
/// 今天/计划/旗标/全部等视图里，同一条目的副标题都是它所属的列表名；
/// 视图名只出现在页面标题。
///
/// 历史：2026-10-27 实测「今天」视图新建项副标题是「今天 · 12:06」——
/// 根因是当时智能视图快加项的 listId 被写成当前视图 id（smart.today），
/// `listTitles[item.listId]` 恰好命中智能列表名。#245 把快加项改落默认
/// 列表后顺带修复；本组断言防止回归（数据面 listId 语义 + 渲染面列表名）。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<InMemoryReminderRepository> seedAndPump(
    WidgetTester tester,
    String openListId,
  ) async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(
      id: 'list.personal',
      title: '个人',
      colorArgb: 0xFFFF9500,
    ));
    await repo.upsertList(const ReminderList(
      id: 'list.work',
      title: '工作',
      colorArgb: 0xFF007AFF,
    ));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9, 5);
    await repo.upsertItem(const ReminderItem(
      id: 'i1',
      listId: 'list.personal',
      title: '个人事项',
    ));
    await repo.upsertItem(ReminderItem(
      id: 'i2',
      listId: 'list.work',
      title: '工作事项',
      dueAt: today,
    ));
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(TaskScaffold(openListId: openListId)),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  /// 副标题由 Text.rich(TextSpan) 渲染，必须用 findRichText 才能取到纯文本。
  Set<String> subtitles(WidgetTester tester) {
    return tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => (r.text as TextSpan).toPlainText().trim())
        .toSet();
  }

  testWidgets('今天视图：带 dueAt 的行副标题 = 所属列表名 · 时刻', (tester) async {
    await seedAndPump(tester, 'smart.today');

    final subs = subtitles(tester);
    expect(
      subs,
      contains('工作 · 09:05'),
      reason: '今天视图里「工作事项」的副标题必须显示所属列表名「工作」，'
          '不能是视图名「今天」',
    );
    expect(
      subs,
      isNot(contains('今天 · 09:05')),
      reason: '视图名混进行副标题就是 #89 P1-6 的回归',
    );
  });

  testWidgets('全部视图：同一条目副标题仍是所属列表名，无 dueAt 也有列表名',
      (tester) async {
    await seedAndPump(tester, 'smart.all');

    final subs = subtitles(tester);
    expect(subs, contains('工作 · 09:05'));
    expect(
      subs,
      contains('个人'),
      reason: '无 dueAt 的条目副标题就是纯列表名（Apple 口径）',
    );
    expect(subs, isNot(contains('全部 · 09:05')));
  });
}
