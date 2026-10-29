// TC-UI-2xx / #446：全天提醒是否按逾期显示的开关。
//
// 语义（卡里写死的口径）：
// - 关（默认）：全天提醒过期也**不**标红，只显示日期；
// - 开：全天提醒过期与定时提醒同待遇（标红）。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpRow(
  WidgetTester tester, {
  required bool allDayAsOverdue,
  required DateTime dueAt,
}) async {
  await tester.pumpWidget(MaterialApp(
    // 固定 zh：`DateFormat.MMMd` 会随 locale 输出「10月28日」而不是「Oct 28」
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: ReminderRow(
        item: ReminderItem(
          id: 'r1',
          listId: 'l1',
          title: '全天提醒',
          dueAt: dueAt,
        ),
        now: DateTime(2026, 10, 29, 15),
        allDayAsOverdue: allDayAsOverdue,
        onToggleCompleted: () {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// 到期文案在 `RichText` 的 `TextSpan` 里（不是独立 `Text`），所以要扫 span：
/// 找到包含目标文案的 span，返回它的颜色（十六进制）；找不到返回 null。
String? _dueTextStyle(WidgetTester tester, String text) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    String? found;
    rich.text.visitChildren((span) {
      if (span is TextSpan && (span.text ?? '').contains(text)) {
        final color = span.style?.color;
        if (color != null) {
          found ??= color.toARGB32().toRadixString(16);
        }
      }
      return true;
    });
    if (found != null) return found;
  }
  return null;
}

void main() {
  testWidgets('#446 关闭（默认）：过期的全天提醒不标红', (tester) async {
    // 昨天的 00:00 = 全天
    await _pumpRow(
      tester,
      allDayAsOverdue: false,
      dueAt: DateTime(2026, 10, 28),
    );

    expect(find.byType(ReminderRow), findsOneWidget);
    final style = _dueTextStyle(tester, '10月28日');
    // 关闭时不加红：span 无自定义颜色（继承默认）
    expect(style, isNull, reason: '关闭时全天过期不该标红（span 不带红色）');
  });

  testWidgets('#446 开启：过期的全天提醒标红（与定时同待遇）', (tester) async {
    await _pumpRow(
      tester,
      allDayAsOverdue: true,
      dueAt: DateTime(2026, 10, 28),
    );

    final style = _dueTextStyle(tester, '10月28日');
    expect(style, isNotNull);
    expect(style!.toUpperCase().contains('FF3B30'), isTrue,
        reason: '开启后应与定时提醒一样标红');
  });

  testWidgets('#446 定时提醒不受开关影响', (tester) async {
    await _pumpRow(
      tester,
      allDayAsOverdue: false,
      dueAt: DateTime(2026, 10, 28, 9, 30),
    );
    final styled = _dueTextStyle(tester, '10月28日');
    // 定时过期行文案可能带时刻；无论哪种都应是红色
    expect(styled, isNotNull);
    expect(styled!.toUpperCase().contains('FF3B30'), isTrue,
        reason: '定时提醒的逾期样式不应受该开关影响');
  });
}
