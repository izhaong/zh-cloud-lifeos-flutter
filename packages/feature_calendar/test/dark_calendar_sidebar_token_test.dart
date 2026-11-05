import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

/// Gitea flutter #295：强制暗色下日历侧栏仍是亮色（实测取样 `#F2F2F7`）。
///
/// 坏在「交给 paint 前没 resolve」：`ColoredBox` / `Container(color:)` 拿到的是
/// `CupertinoDynamicColor` 本身，它未解算时 `value` 就是**亮档**——同一次会话里
/// 任务侧栏与日历主区都是暗的，只有日历侧栏掉队。
///
/// 断言只量「实际会被画出来的那串 ARGB」（`toARGB32()` 走 `_effectiveColor`），
/// 不比对对象类型：`resolveFrom` 的返回值仍是 `CupertinoDynamicColor`，类型断言
/// 既判不出对错也没有意义。骨架用 `CalendarScaffold`（1280×900 宽屏档，
/// 侧栏 + 横竖发丝线都在树里），不锁机器时区、不联网。
void main() {
  const lightGrouped = 0xFFF2F2F7; // CalendarTokens.groupedBackground 亮档
  const darkGrouped = 0xFF1C1C1E; // 同一令牌暗档（Apple systemGroupedBackground）

  Future<void> pumpCalendar(WidgetTester tester, Brightness brightness) async {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1.0;
    tester.binding.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(
            _StubCalendarRepository(),
          ),
        ],
        child: lifeTestHost(const CalendarScaffold()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 侧栏底色 = `calendar_sidebar` 子树里第一个 `ColoredBox`（外层背板）。
  int sidebarBackdrop(WidgetTester tester) {
    final boxes = tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byKey(const Key('calendar_sidebar')),
            matching: find.byType(ColoredBox),
          ),
        )
        .toList();
    expect(boxes, isNotEmpty, reason: '侧栏背板没渲染，断言就成了恒真');
    return boxes.first.color.toARGB32();
  }

  /// 骨架里所有「≤1px 薄条」paint 位（横竖发丝线）用到的颜色 ARGB。
  List<int> hairlineColors(WidgetTester tester) {
    final out = <int>[];
    for (final box in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
      if (tester.getSize(find.byWidgetPredicate((w) => w == box)).width <= 1.0) {
        out.add(box.color.toARGB32());
      }
    }
    for (final c in tester.widgetList<Container>(find.byType(Container))) {
      final color = c.color;
      if (color == null) continue;
      if (tester.getSize(find.byWidgetPredicate((w) => w == c)).height <= 1.0) {
        out.add(color.toARGB32());
      }
    }
    return out;
  }

  testWidgets('暗色档：侧栏底色解算成暗色（#295 现象面）', (tester) async {
    await pumpCalendar(tester, Brightness.dark);
    expect(sidebarBackdrop(tester), darkGrouped);
  });

  // 灵敏度对照：同一个断言位在亮色档必须回到亮值，否则上面那条「暗」是恒真。
  testWidgets('亮色档：侧栏底色仍是 F2F2F7（亮度真的在驱动取值）', (tester) async {
    await pumpCalendar(tester, Brightness.light);
    expect(sidebarBackdrop(tester), lightGrouped);
  });

  testWidgets('暗色档：发丝线也按暗色解算（同一 paint 模式的其余位）', (tester) async {
    await pumpCalendar(tester, Brightness.dark);
    final colors = hairlineColors(tester);
    expect(colors, isNotEmpty, reason: '没量到发丝线=断言恒真');
    // CupertinoColors.separator 亮档 = 0x493C3C43；暗档 alpha 更高、通道不同。
    for (final argb in colors) {
      expect(
        argb,
        isNot(lightSeparatorArgb),
        reason: '发丝线拿到的是未解算的亮档（#295 同一模式）',
      );
    }
  });

  // 灵敏度对照：亮色档这些薄条本来就画亮档值，证明上一条判据是亮度在驱动。
  testWidgets('亮色档：发丝线仍是亮档 separator', (tester) async {
    await pumpCalendar(tester, Brightness.light);
    final colors = hairlineColors(tester);
    // 网格线等其它薄条用的是不透明令牌，不在本单口径里；这里只要求
    // 「用到半透明 separator 的那些位」在亮档确实画亮值。
    expect(colors, contains(lightSeparatorArgb));
  });
}

/// `CupertinoColors.separator` 未解算时的亮档 ARGB（半透明，故 alpha 也参与比对）。
const lightSeparatorArgb = 0x493C3C43;

class _StubCalendarRepository implements CalendarRepository {
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
  Future<CalendarEvent?> getEvent(String id) async => null;

  @override
  Future<void> upsertCalendar(Calendar c) async {}

  @override
  Future<void> deleteCalendar(String id) async {}

  @override
  Future<void> setDefaultCalendar(String id) async {}

  @override
  Future<void> reorderCalendars(List<String> ids) async {}

  @override
  Future<void> setVisibility({
    String? id,
    bool? visible,
    bool? allVisible,
    String? onlyId,
  }) async {}

  @override
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    return e.id;
  }

  @override
  Future<void> deleteEvent(
    String id, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {}

  @override
  Future<void> moveEvent(String id, String targetCalendarId) async {}

  @override
  Future<List<CalendarEvent>> search(
    String keyword, {
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) async {
    return const [];
  }

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(CalendarPreference.defaults);

  @override
  Future<void> savePreference(CalendarPreference p) async {}
}
