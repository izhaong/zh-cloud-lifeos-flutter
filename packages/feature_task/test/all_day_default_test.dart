import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'support/life_test_app.dart';

/// TC-KR-101（时间语义与全天默认）：全天提醒默认 9:00 提醒时点。
///
/// 实现层：`reminder_detail_pane.dart` 的「全天」开关（ValueKey `due_at_all_day`）
/// 关闭时把时点落到 `DateTime(y, m, d, 9, 0)`（行 299-307）。kernel 的
/// `ReminderItem` 无 allDay 概念，因此这是客户端唯一承载「全天默认 9:00」语义的点。
///
/// 此前全仓 test 目录对 `due_at_all_day` 零引用——本文件补上客户端断言。
void main() {
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('TC-KR-101 全天默认 9:00', () {
    testWidgets('全天关闭 → 提醒时点落到 09:00', (tester) async {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(900, 1300);
      view.devicePixelRatio = 1.0;

      final repo = InMemoryReminderRepository(seedSampleData: false);
      await repo.upsertList(
        const ReminderList(id: 'list.t', title: '测试', colorArgb: 0xFF007AFF),
      );
      // 午夜 = 全天：开关初始为 ON
      final item = ReminderItem(
        id: 'r1',
        listId: 'list.t',
        title: '生日',
        dueAt: DateTime(2026, 1, 15, 0, 0),
      );

      ReminderItem? saved;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
          child: lifeTestHost(
            ReminderDetailPane(
              item: item,
              onSaved: (u) {
                saved = u;
                // 回调里无法 await：显式 unawaited 表明「故意不等待」，
                // 后面用 watchItems 二次断言兜底（#433 守卫要求这种写法）。
                unawaited(repo.upsertItem(u));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 打开「日期与时间」选择器
      await tester.tap(find.byKey(const Key('due_at_row')));
      await tester.pumpAndSettle();

      // 全天开关当前为 ON（午夜）；关掉它 → 默认 09:00
      final allDay = find.byKey(const Key('due_at_all_day'));
      expect(allDay, findsOneWidget, reason: 'due_at_all_day 开关存在');
      await tester.tap(allDay);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('due_at_confirm')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('detail_save')));
      await tester.tap(find.byKey(const Key('detail_save')));
      await tester.pumpAndSettle();

      expect(saved, isNotNull, reason: '应触发 onSaved');
      expect(saved!.dueAt, isNotNull, reason: 'dueAt 不应被清空');
      expect(saved!.dueAt!.hour, 9, reason: '关闭全天 → 默认 09:00 时点');
      expect(saved!.dueAt!.minute, 0, reason: '分钟归零');

      // 落库口径一致
      final stored = await repo
          .watchItems()
          .first
          .then((all) => all.singleWhere((e) => e.id == 'r1'));
      expect(stored.dueAt!.hour, 9);
      expect(stored.dueAt!.minute, 0);
    });

    testWidgets('普通时间确认不强制 9:00（证明 9:00 仅全天关闭默认）', (tester) async {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(900, 1300);
      view.devicePixelRatio = 1.0;

      final repo = InMemoryReminderRepository(seedSampleData: false);
      await repo.upsertList(
        const ReminderList(id: 'list.t', title: '测试', colorArgb: 0xFF007AFF),
      );
      // 14:30 非全天：开关初始为 OFF，确认应保留原时点
      final item = ReminderItem(
        id: 'r2',
        listId: 'list.t',
        title: '会议',
        dueAt: DateTime(2026, 3, 2, 14, 30),
      );

      ReminderItem? saved;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
          child: lifeTestHost(
            ReminderDetailPane(
              item: item,
              onSaved: (u) => saved = u,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('due_at_row')));
      await tester.pumpAndSettle();

      // 不碰开关，直接确认
      await tester.tap(find.byKey(const Key('due_at_confirm')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('detail_save')));
      await tester.tap(find.byKey(const Key('detail_save')));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.dueAt!.hour, 14, reason: '非全天时点应原样保留，而非被改到 9:00');
      expect(saved!.dueAt!.minute, 30);
    });
  });
}
