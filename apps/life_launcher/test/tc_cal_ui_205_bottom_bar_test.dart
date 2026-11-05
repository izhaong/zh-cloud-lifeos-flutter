import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/main.dart';
import 'package:life_launcher/shell/pinned_tabs_service.dart';
import 'package:life_launcher/shell_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TC-CAL-UI-205（#607 档 A 第七批）：iPhone 档打开新建表单时，底栏仍在且仍选中「日历」。
///
/// 台账这句看着轻，坏起来很常见：表单如果是整页 push（而不是叠在壳上的弹层），
/// 底栏会被换掉，用户保存后发现自己被丢回首页；即使弹层没错，选中态也容易被重建成 0，
/// 底栏还在但高亮跳走。所以量两件——底栏在树里、`items[currentIndex].label` 仍是「日历」，
/// 并且「打开前」先取一次同样的读数当锚（打开前后必须一致，否则「仍」字没有对照）。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// 底栏当前选中项的 label（没有底栏返回 null）。
  String? selectedLabel(WidgetTester tester) {
    final found = find.byType(CupertinoTabBar);
    if (found.evaluate().isEmpty) return null;
    final bar = tester.widget<CupertinoTabBar>(found);
    return bar.items[bar.currentIndex].label;
  }

  testWidgets('TC-CAL-UI-205 打开新建日程表单后，底栏仍在且仍选中日历', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(375, 812)
      ..devicePixelRatio = 1.0;
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(
            InMemoryReminderRepository(),
          ),
          calendarRepositoryProvider.overrideWithValue(
            _FakeCalendarRepository(),
          ),
          pinnedTabsServiceProvider.overrideWithValue(PinnedTabsService(prefs)),
          shellBadgeCountsProvider.overrideWithValue(const {}),
        ],
        child: const LifeLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar_toolbar')),
      findsOneWidget,
      reason: '先进到日历档',
    );
    expect(selectedLabel(tester), '日历', reason: '锚：打开表单前选中的就是日历');

    await tester.tap(find.byKey(const Key('quick_create_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_create_event')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('quick_event_dialog')),
      findsOneWidget,
      reason: '表单没打开，后面两条断言就成了空转',
    );
    expect(
      find.byType(CupertinoTabBar),
      findsOneWidget,
      reason: '表单把底栏换掉 = 保存后用户被丢回首页那一类',
    );
    expect(selectedLabel(tester), '日历', reason: '底栏还在但高亮跳走，同样是「仍显示日历为选中」没满足');
  });
}

class _FakeCalendarRepository implements CalendarRepository {
  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(const []);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) {
    return Stream.value(const []);
  }

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(CalendarPreference.defaults);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
