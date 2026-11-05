import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SmartListCard 渐变/标题/计数/点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 60,
              child: SmartListCard(
                list: const ReminderList(
                  id: 'smart.today',
                  title: '今天',
                  isSmart: true,
                  itemCount: 3,
                ),
                selected: false,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );

    const key = ValueKey('smart_card_smart.today');
    expect(find.byKey(key), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('smart_card_surface_smart.today')),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.gradient, isNotNull);

    await tester.tap(find.byKey(key));
    expect(taps, 1);
  });

  testWidgets('SmartListCard 选中态有描边', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 60,
              child: SmartListCard(
                list: const ReminderList(
                  id: 'smart.flagged',
                  title: '旗标',
                  isSmart: true,
                  itemCount: 0,
                ),
                selected: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('smart_card_surface_smart.flagged')),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
  });
}
