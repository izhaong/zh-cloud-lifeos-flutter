import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget row) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: row),
    ),
  );
}

Text _subtitle(WidgetTester tester, String needle) {
  return tester.widget<Text>(
    find.byWidgetPredicate(
      (w) => w is Text && (w.textSpan?.toPlainText().contains(needle) ?? false),
    ),
  );
}

void main() {
  testWidgets('ReminderRow 副标题：列表名 + 逾期日期标红', (tester) async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1, 9);
    await _pump(
      tester,
      ReminderRow(
        item: ReminderItem(
          id: 'i1',
          listId: 'list.personal',
          title: '交报告',
          dueAt: yesterday,
        ),
        listName: '个人',
        onToggleCompleted: () {},
      ),
    );

    final subtitle = _subtitle(tester, '个人');
    final spans = (subtitle.textSpan as TextSpan).children!
        .whereType<TextSpan>()
        .toList();
    expect(
      spans.any((s) => s.text == '个人'),
      isTrue,
      reason: '副标题必须包含真实列表名',
    );
    final dateSpan = spans.firstWhere(
      (s) => s.style?.color == ReminderTokens.systemRed,
      orElse: () => throw StateError('未找到红色逾期日期片段'),
    );
    expect(dateSpan.text, isNotEmpty, reason: '逾期日期必须非空且标红');
  });

  testWidgets('ReminderRow 副标题：今天带时间显示 HH:mm', (tester) async {
    final now = DateTime.now();
    final todayAt = DateTime(now.year, now.month, now.day, 14, 30);
    await _pump(
      tester,
      ReminderRow(
        item: ReminderItem(
          id: 'i1',
          listId: 'list.personal',
          title: '开会',
          dueAt: todayAt,
        ),
        listName: '个人',
        onToggleCompleted: () {},
      ),
    );

    final subtitle = _subtitle(tester, '14:30');
    expect(subtitle.textSpan!.toPlainText(), contains('14:30'));
    expect(subtitle.textSpan!.toPlainText(), contains('个人'));
  });
}
