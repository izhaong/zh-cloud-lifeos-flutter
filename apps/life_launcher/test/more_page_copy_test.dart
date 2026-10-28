import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/main.dart';
import 'package:life_launcher/shell/pinned_tabs_service.dart';
import 'package:life_launcher/shell_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// #238：壳层「更多」页的目录入口副标题不能把设计文档的内部行号（H1）泄漏给用户。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('「添加更多应用」副标题只描述动作，不含内部编号', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(375, 812)
      ..devicePixelRatio = 1.0;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(
            InMemoryReminderRepository(),
          ),
          pinnedTabsServiceProvider.overrideWithValue(PinnedTabsService(prefs)),
        ],
        child: const LifeLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('添加更多应用'),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text('浏览并安装更多 LifeOS 应用'),
      findsOneWidget,
      reason: '目录入口副标题要是面向用户的动作描述',
    );
    expect(
      find.textContaining('H1'),
      findsNothing,
      reason: '设计文档的内部行号不得出现在界面',
    );
  });
}
