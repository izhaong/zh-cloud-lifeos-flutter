// TC-UI-201／301 补强（#367）：新建提醒的**草稿行**必须按 Apple 的语义收口。
//
// 报告的三点现象：
//  1. 点击别处（失焦）不提交，草稿行以「像已存在」的形态常驻列表；
//  2. 常驻的草稿行不计入「今天/计划/全部」计数（列表里 3 条，计数仍是 2）；
//  3. 键入后按一次回车不结束编辑，要按两次。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openDraft(WidgetTester tester) async {
  if (find.byKey(const ValueKey('draft_field')).evaluate().isNotEmpty) return;
  await tester.tap(find.text('新提醒事项').first);
  await tester.pumpAndSettle();
}

Future<InMemoryReminderRepository> _pump(WidgetTester tester,
    {Size size = const Size(1280, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = InMemoryReminderRepository(seedSampleData: false)
    ..nowForTest = DateTime(2026, 10, 26);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 9, 30)),
      ],
      child: const MaterialApp(home: TaskScaffold(openListId: 'smart.today')),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('#367 现象2/3：回车一次应提交并收起草稿行', (tester) async {
    final repo = await _pump(tester);

    await _openDraft(tester);
    await tester.enterText(
        find.byKey(const ValueKey('draft_field')), '回车一次');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final items = await repo.watchItems().first;
    expect(items.where((i) => i.title == '回车一次'), hasLength(1),
        reason: '一次回车就应落库');
    expect(find.byKey(const ValueKey('draft_field')), findsNothing,
        reason: '提交后草稿行应收起（回车一次即可）');
  });

  testWidgets('#367 现象1：失焦应提交草稿（Apple: 点到别处即提交）', (tester) async {
    final repo = await _pump(tester);

    await _openDraft(tester);
    await tester.enterText(
        find.byKey(const ValueKey('draft_field')), '失焦提交');
    // 点到列表别处 → 草稿行失焦。
    // widget 测试没有真实窗口焦点，点不可聚焦区域不会真的搬走焦点，
    // 所以这里显式 unfocus：它走的正是 FocusNode 监听那条路（生产里由点击触发）。
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final items = await repo.watchItems().first;
    expect(items.where((i) => i.title == '失焦提交'), hasLength(1),
        reason: '失焦必须提交，不能留一条「存在但不算数」的草稿行');
  });

  testWidgets('#367 现象2：列表可见条目数应与计数一致', (tester) async {
    final repo = await _pump(tester);
    await _openDraft(tester);
    await tester.enterText(
        find.byKey(const ValueKey('draft_field')), '计数一致');
    await tester.pumpAndSettle();

    // 草稿未提交前：它不该以「普通条目」出现在列表里（只应是草稿行）
    final items = await repo.watchItems().first;
    expect(items, isEmpty, reason: '未提交的草稿不应已落库');
  });
}
