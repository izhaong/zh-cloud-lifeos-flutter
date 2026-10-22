import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/main.dart';

void main() {
  testWidgets('shell boots with 任务 tab', (tester) async {
    await tester.pumpWidget(
      LifeLauncherApp(reminderRepository: InMemoryReminderRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('提醒事项'), findsOneWidget);
    expect(find.text('更多'), findsWidgets);
  });
}
