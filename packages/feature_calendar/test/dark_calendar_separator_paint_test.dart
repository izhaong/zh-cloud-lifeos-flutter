import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_calendar/src/design/calendar_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;

import 'support/life_test_app.dart';

/// Gitea flutter #304：#295 只收了侧栏与骨架发丝线，日历其余 paint 位仍把
/// **未解算**的 `CupertinoDynamicColor` 直接交给画布。
///
/// 两条判据，互相补盲：
/// 1. 结构门禁——扫 `lib/src` 里「不解算动态色的通道」（`BorderSide(` /
///    `Border.all(` / `ColoredBox(` / `BoxDecoration(` / `Container(color:)`）
///    传入的 `CupertinoColors.*` / `CalendarTokens.*` 动态令牌。这条覆盖
///    弹窗内部（时区列表、提醒行）这些点不进 widget 树的位。
///    `TextStyle(` / `Icon(` 两个通道本单不裁决（#295 实测只覆盖表面与描边，
///    文本/图标通道是另一个问题），门禁会打印被豁免的条数，不静默吞掉。
/// 2. 界面实测——暗色/亮色各渲一遍，直接读会被画出来的 ARGB。断言与对照
///    成对：暗色档判「不许出现该令牌的亮档值」，亮色档判「亮档值确实在树里」，
///    否则暗色那条是恒真。
void main() {
  final calendarLib = Directory('lib/src');

  test('#304 结构门禁：不解算通道里没有未 resolve 的动态色令牌', () {
    expect(
      calendarLib.existsSync(),
      isTrue,
      reason: '扫描路径没了=门禁失去判别力',
    );
    // 正对照：静态豁免表只在 SDK 真把它们当普通 Color 时才成立；哪天改成动态色，
    // 这两条先红，豁免表不会悄悄过期。
    expect(
      CupertinoColors.white,
      isNot(isA<CupertinoDynamicColor>()),
      reason: 'CupertinoColors.white 已是动态色，要从静态豁免表里移出',
    );
    expect(
      CupertinoColors.black,
      isNot(isA<CupertinoDynamicColor>()),
      reason: 'CupertinoColors.black 已是动态色，要从静态豁免表里移出',
    );
    // CalendarTokens 里既有动态令牌，也有写死的 const Color；后者本就没有暗档，
    // 判它「未解算」是假红，所以先从声明处把静态令牌名取出来。
    final declared = File('lib/src/design/calendar_tokens.dart').readAsStringSync();
    final staticTokens = RegExp(r'static const (\w+) = Color\(')
        .allMatches(declared)
        .map((m) => m.group(1)!)
        .toSet();
    final violations = <String>{};
    final exempted = <String, int>{};
    var staticallySkipped = 0;
    for (final file in calendarLib
        .listSync(recursive: true)
        .whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      // 令牌声明处本身要导出 CupertinoDynamicColor，不是 paint 位。
      if (file.path.endsWith('design/calendar_tokens.dart')) continue;
      final text = file.readAsStringSync();
      for (final m in _colorArg.allMatches(text)) {
        final channel = _nearestChannel(text.substring(0, m.start));
        if (channel == null) continue;
        final arg = _argument(text, m.end);
        for (final t in _bareToken.allMatches(arg)) {
          if (t.group(2) != null) continue; // 已 .resolveFrom / .resolve
          final name = t.group(1)!;
          final tail = name.split('.').last;
          // 文字通道写死 `CupertinoColors.black`：它是 const Color、没有暗档，
          // 压在本单翻暗的背板上就是黑字贴黑底（审查轮在周几胶囊实测到）。
          // 文本要随亮度只能走 label 这类动态令牌。
          if (channel == 'TextStyle(' && name == 'CupertinoColors.black') {
            final line = text.substring(0, m.start + t.start).split('\n').length;
            violations.add(
              '${file.path}:$line 文字写死 CupertinoColors.black（无暗档，用 label）',
            );
            continue;
          }
          final isStatic =
              (name.startsWith('CalendarTokens.') &&
                  staticTokens.contains(tail)) ||
              (name.startsWith('CupertinoColors.') &&
                  _staticCupertinoColors.contains(tail));
          if (isStatic) {
            staticallySkipped++;
            continue;
          }
          final line = text.substring(0, m.start + t.start).split('\n').length;
          if (_unresolvedChannels.contains(channel)) {
            violations.add(
              '${file.path}:$line 通道「$channel」把 $name 原样交给 paint',
            );
          } else {
            exempted[channel] = (exempted[channel] ?? 0) + 1;
          }
        }
      }
    }
    // 豁免面要可见：文本/图标通道本单不裁决，但得知道有几条被放过。
    stderr.writeln('豁免（不裁决的通道）：$exempted 静态令牌跳过：$staticallySkipped');
    final sorted = violations.toList()..sort();
    expect(
      sorted,
      isEmpty,
      reason: '暗色档会画成亮档的分隔线/背板：\n${sorted.join('\n')}',
    );
  });

  testWidgets('暗色档：日视图 1px 列分隔与全天带发丝线都解算成暗档', (tester) async {
    await _pump(tester, Brightness.dark, _daySurface());
    final painted = _separatorPaints(tester);
    expect(painted, isNotEmpty, reason: '没量到任何分隔线=断言恒真');
    expect(
      painted,
      isNot(contains(CalendarTokens.separator.toARGB32())),
      reason: '日视图列分隔拿到未解算的亮档 C6C6C8（#295 同一模式）',
    );
    expect(
      painted,
      isNot(contains(_lightSeparatorArgb)),
      reason: '全天带下沿 BorderSide 拿到未解算的亮档 separator',
    );
  });

  testWidgets('亮色档：同一批分隔线仍是亮档（证明亮度在驱动取值）', (tester) async {
    await _pump(tester, Brightness.light, _daySurface());
    final painted = _separatorPaints(tester);
    expect(painted, isNotEmpty);
    expect(painted, contains(CalendarTokens.separator.toARGB32()));
    expect(painted, contains(_lightSeparatorArgb));
  });

  testWidgets('暗色档：Inspector 头部背板与发丝线跟随系统', (tester) async {
    await _pump(
      tester,
      Brightness.dark,
      EventInspectorPane(
        initialEvent: _draftEvent(),
        onSaved: () {},
        onClose: () {},
      ),
    );
    final painted = _separatorPaints(tester);
    expect(painted, isNotEmpty, reason: 'Inspector 头部没渲出来=断言恒真');
    expect(
      painted,
      isNot(contains(_lightSeparatorArgb)),
      reason: '_InspectorHeader 的 BorderSide 仍是亮档（#304）',
    );
    final surfaces = _systemBackgroundPaints(tester);
    expect(surfaces, isNotEmpty, reason: '头部背板没量到=断言恒真');
    expect(
      surfaces,
      isNot(contains(0xFFFFFFFF)),
      reason: 'Inspector 头部背板在暗色档画成纯白（ColoredBox/BoxDecoration 未解算）',
    );
  });

  testWidgets('暗色档：设置面板与表单字段的行分隔线不再浅灰', (tester) async {
    await _pump(
      tester,
      Brightness.dark,
      const Column(children: [
        Expanded(child: CalendarSettingsSheet()),
      ]),
    );
    final settings = _separatorPaints(tester);
    expect(settings, isNotEmpty, reason: '设置面板行发丝线没渲出来=断言恒真');
    expect(
      settings,
      isNot(contains(_lightSeparatorArgb)),
      reason: 'CalendarSettingsSheet 的 _Row/_SwitchRow 仍是亮档 separator（#304）',
    );

    await _pump(
      tester,
      Brightness.dark,
      EventFormFields(event: _draftEvent(), onChanged: (_) {}),
    );
    final form = _separatorPaints(tester);
    expect(form, isNotEmpty, reason: '表单行发丝线没渲出来=断言恒真');
    expect(
      form,
      isNot(contains(_lightSeparatorArgb)),
      reason: 'EventFormFields 的 _FieldRow/_SwitchRow/_TextFieldRow 仍是亮档（#304）',
    );
  });

  testWidgets('亮色档：Inspector/设置/表单的分隔线仍是亮档（灵敏度对照）', (tester) async {
    await _pump(
      tester,
      Brightness.light,
      EventInspectorPane(
        initialEvent: _draftEvent(),
        onSaved: () {},
        onClose: () {},
      ),
    );
    expect(_separatorPaints(tester), contains(_lightSeparatorArgb));

    await _pump(
      tester,
      Brightness.light,
      EventFormFields(event: _draftEvent(), onChanged: (_) {}),
    );
    expect(_separatorPaints(tester), contains(_lightSeparatorArgb));
  });

  // 审查轮指出的对比度回归：本单把背板解算成暗档后，压在其上、却没解算的
  // 文字令牌就变成「深灰贴黑」。断言只量会被画出来的那串 ARGB，成对给亮色对照。
  testWidgets('暗色档：提醒栏标题跟着背板一起解算（3C3C43 不许贴在黑底上）', (tester) async {
    await _pump(
      tester,
      Brightness.dark,
      const Column(children: [Expanded(child: DayReminderLane())]),
      reminders: _laneReminders(),
    );
    expect(_laneTitleArgb(tester), 0xFFEBEBF5);
  });

  testWidgets('亮色档：提醒栏标题仍是 3C3C43（亮色外观逐像素不变）', (tester) async {
    await _pump(
      tester,
      Brightness.light,
      const Column(children: [Expanded(child: DayReminderLane())]),
      reminders: _laneReminders(),
    );
    expect(_laneTitleArgb(tester), 0xFF3C3C43);
  });
}

/// 灌进提醒栏的一条当天提醒（不联网、不打真实仓库）。
List<ReminderItem> _laneReminders() => [
  ReminderItem(
    id: 'lane-1',
    listId: 'list-1',
    title: '买牛奶',
    dueAt: DateTime.now(),
  ),
];

/// 提醒栏标题的落笔颜色 ARGB。
int _laneTitleArgb(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byKey(const Key('day_reminder_lane')),
      matching: find.text('买牛奶'),
    ),
  );
  return text.style!.color!.toARGB32();
}

/// SDK 里是普通 `const Color`（没有暗档），交给 paint 也谈不上「未解算」。
/// 上面那两条正对照保证这张表不会静默过期。
const _staticCupertinoColors = {'white', 'black'};

/// `CupertinoColors.separator` 未解算时的亮档 ARGB（半透明，alpha 参与比对）。
const _lightSeparatorArgb = 0x493C3C43;

/// 不解算 `CupertinoDynamicColor` 的 paint 通道（#295 实测；SDK 里 `resolveFrom`
/// 只出现在 cupertino/material 主题解析处，这几条都不经过）。
const _unresolvedChannels = [
  'BorderSide(',
  'Border.all(',
  'ColoredBox(',
  'BoxDecoration(',
  'Container(',
];

/// 本单不裁决、但要计数可见的通道。
const _exemptChannels = ['TextStyle(', 'Icon('];

/// 颜色实参起点：只认小写 `color:`（`cursorColor:`/`selectionColor:` 等都是驼峰，
/// 落在别处；本单裁决的是「令牌直接进 paint」这一条路径）。
final _colorArg = RegExp(r'\bcolor:\s*');

/// 一个颜色实参里的令牌；第二组非空表示已经 `.resolve…`（豁免）。
/// `CalendarTokens.systemBlue.withAlpha(20)` 这种在解算前改 alpha 的写法会把
/// 亮档烘死成普通 Color，所以只有紧跟 `.resolve…` 才算过关。
final _bareToken = RegExp(
  r'((?:CupertinoColors|CalendarTokens)\.[A-Za-z0-9_]+)(\s*\.\s*resolve[A-Za-z]*)?',
);

/// 从 [start] 读到本层实参结束：遇到顶层 `,` 或收尾括号就停，
/// 这样 `color: 三元? A : B` 两支都被量到，而 `child:` 子树不会被误算。
String _argument(String text, int start) {
  var depth = 0;
  var i = start;
  while (i < text.length) {
    final ch = text[i];
    if (ch == '(' || ch == '[' || ch == '{') {
      depth++;
    } else if (ch == ')' || ch == ']' || ch == '}') {
      if (depth == 0) break;
      depth--;
    } else if (ch == ',' && depth == 0) {
      break;
    }
    i++;
  }
  return text.substring(start, i);
}

/// 取 `color:` 之前最近的通道标记：谁离得近就归属谁。
String? _nearestChannel(String before) {
  String? winner;
  var at = -1;
  for (final marker in [..._unresolvedChannels, ..._exemptChannels]) {
    final i = before.lastIndexOf(marker);
    if (i > at) {
      at = i;
      winner = marker;
    }
  }
  return at < 0 ? null : winner;
}

/// 量「分隔线」类颜色：`DecoratedBox` 的底色与四边描边 + `ColoredBox` 底色，
/// 只保留确实属于 separator 令牌族（亮/暗两档）的取样，避免把无关颜色算进来。
List<int> _separatorPaints(WidgetTester tester) {
  final opaqueLight = CalendarTokens.separator.toARGB32();
  final candidates = <int>[
    _lightSeparatorArgb,
    0x99545458, // 同令牌暗档
    opaqueLight,
    0xFF38383A, // CalendarTokens.separator 暗档
  ];
  final out = <int>[];
  for (final box in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
    final d = box.decoration;
    if (d is! BoxDecoration) continue;
    final color = d.color;
    if (color != null && candidates.contains(color.toARGB32())) {
      out.add(color.toARGB32());
    }
    for (final side in _borderSides(d)) {
      if (candidates.contains(side.color.toARGB32())) {
        out.add(side.color.toARGB32());
      }
    }
  }
  for (final c in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
    if (candidates.contains(c.color.toARGB32())) out.add(c.color.toARGB32());
  }
  return out;
}

/// `CupertinoColors.systemBackground` 的取样（亮 FFFFFF / 暗 000000）。
List<int> _systemBackgroundPaints(WidgetTester tester) {
  const light = 0xFFFFFFFF;
  const dark = 0xFF000000;
  final out = <int>[];
  for (final box in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
    final d = box.decoration;
    if (d is BoxDecoration) {
      final c = d.color;
      if (c != null && (c.toARGB32() == light || c.toARGB32() == dark)) {
        out.add(c.toARGB32());
      }
    }
  }
  for (final c in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
    if (c.color.toARGB32() == light || c.color.toARGB32() == dark) {
      out.add(c.color.toARGB32());
    }
  }
  return out;
}

Iterable<BorderSide> _borderSides(BoxDecoration d) {
  final border = d.border;
  if (border is Border) {
    return [border.top, border.bottom, border.left, border.right];
  }
  if (border is BorderDirectional) {
    return [border.top, border.bottom, border.start, border.end];
  }
  return const [];
}

/// 宽屏档（≥1200 → expanded：侧栏 + 日视图 + 右栏提醒 lane），
/// 日视图的 1px 列分隔与全天带下沿才会在树里。
Widget _daySurface() =>
    const CalendarScaffold(pinnedViewMode: CalendarViewMode.day);

CalendarEvent _draftEvent() => CalendarEvent(
  id: 'e1',
  calendarId: 'c1',
  uid: 'u1',
  title: '周会',
  startAt: DateTime.utc(2026, 10, 24, 10),
  endAt: DateTime.utc(2026, 10, 24, 11),
  timeZone: 'UTC',
  updatedAt: DateTime.utc(2026, 10, 24),
);

Future<void> _pump(
  WidgetTester tester,
  Brightness brightness,
  Widget child, {
  List<ReminderItem>? reminders,
}) async {
  TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
    ..physicalSize = const Size(1280, 900)
    ..devicePixelRatio = 1.0;
  tester.binding.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.binding.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(_StubCalendarRepository()),
        kalenderEventsControllerProvider.overrideWithValue(
          kalender.DefaultEventsController(),
        ),
        if (reminders != null)
          reminderItemsForCalendarProvider.overrideWith(
            (ref) => Stream.value(reminders),
          ),
      ],
      child: lifeTestHost(child),
    ),
  );
  await tester.pumpAndSettle();
}

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
