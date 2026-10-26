import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart' as kalender;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'logic/event_time.dart';
import 'logic/search_filter.dart';

/// 日历视图模式（契约 §5.4 viewModeProvider；iPhone 列表档含 list）。
enum CalendarViewMode { day, week, month, year, list }

/// 仓库契约 Provider：feature_calendar 内定义与消费，组合根（life_launcher）注入实现。
///
/// 默认抛错：未注入即显式失败（照 reminderRepositoryProvider 口径，契约 §5.4）。
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  throw StateError(
    'CalendarRepository 未注入：请在组合根 ProviderScope.overrides '
    '中 overrideWith 提供 CalendarRepository 实现。',
  );
}, name: 'calendarRepositoryProvider');

/// 全部日历（侧栏数据；含 isVisible/isDefault/组名）。
final calendarsProvider = StreamProvider<List<Calendar>>((ref) {
  return ref.watch(calendarRepositoryProvider).watchCalendars();
});

/// 可见日历 id 集合（侧栏勾选过滤主视图；TC-CAL-UI-120 消费）。
final visibleCalendarIdsProvider = Provider<Set<String>>((ref) {
  final calendars = ref.watch(calendarsProvider).value ?? const <Calendar>[];
  return {
    for (final c in calendars)
      if (c.isVisible) c.id,
  };
});

/// 锚点日期（工具栏 ‹ 今天 › 与各视图共用；默认今天本地零点）。
final anchorDateProvider =
    NotifierProvider<AnchorDateNotifier, DateTime>(AnchorDateNotifier.new);

class AnchorDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void set(DateTime value) => state = value;

  /// 回到今天。
  void today() => build();
}

/// 视图模式。
final viewModeProvider =
    NotifierProvider<ViewModeNotifier, CalendarViewMode>(ViewModeNotifier.new);

class ViewModeNotifier extends Notifier<CalendarViewMode> {
  @override
  CalendarViewMode build() => CalendarViewMode.day;

  void set(CalendarViewMode value) => state = value;
}

/// 用户偏好（未保存时仓库层回契约 §2.9 默认值）。
final preferenceProvider = StreamProvider<CalendarPreference>((ref) {
  return ref.watch(calendarRepositoryProvider).watchPreference();
});

/// 设备本地时区（flutter_timezone；无插件环境回退 UTC；F-09）。
final deviceTimeZoneProvider = FutureProvider<String>((ref) {
  return deviceTimeZoneName();
});

/// 草稿是否由某个 occurrence 打开（重复事件作用域用；F-10）。
final draftOccurrenceStartProvider =
    NotifierProvider<DraftOccurrenceStartNotifier, DateTime?>(
        DraftOccurrenceStartNotifier.new);

class DraftOccurrenceStartNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void set(DateTime? value) => state = value;
}

/// 全局搜索词（工具栏搜索 / ⌘F 聚焦；空串 = 不过滤；F-13 消费）。
final searchQueryProvider =
    NotifierProvider<CalendarSearchQueryNotifier, String>(
        CalendarSearchQueryNotifier.new);

class CalendarSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

/// 搜索框是否展开（⌘F / 工具栏放大镜；F-13）。
final searchActiveProvider =
    NotifierProvider<SearchActiveNotifier, bool>(SearchActiveNotifier.new);

class SearchActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// 选中 occurrence（Inspector 第三栏 / 点击详情；F-08 消费）。
final selectedOccurrenceProvider = NotifierProvider<SelectedOccurrenceNotifier,
    CalendarOccurrence?>(SelectedOccurrenceNotifier.new);

class SelectedOccurrenceNotifier extends Notifier<CalendarOccurrence?> {
  @override
  CalendarOccurrence? build() => null;

  void select(CalendarOccurrence? value) => state = value;
}

/// 时间窗 occurrence 家族：`ref.watch(occurrencesProvider((from, to)))`。
///
/// 仓库窗口查询 + kernel `expandOccurrences` 纯函数展开（exdates/例外行/颜色）。
final occurrencesProvider = StreamProvider.family<List<CalendarOccurrence>,
    (DateTime, DateTime)>((ref, range) {
  final (from, to) = range;
  final calendars = ref.watch(calendarsProvider).value ?? const <Calendar>[];
  final query = ref.watch(searchQueryProvider);
  final colorByCalendar = {
    for (final c in calendars) c.id: c.colorArgb,
  };
  return ref.watch(calendarRepositoryProvider).watchEvents(from: from, to: to).map((events) {
    final filtered = query.trim().isEmpty
        ? events
        : events
            .where((e) => matchesCalendarSearch(e, query))
            .toList(growable: false);
    return expandOccurrences(filtered,
        from: from, to: to, colorByCalendar: colorByCalendar);
  });
});

/// sheet/全屏 Inspector 路由在途标记（防宽度跨档双开编辑面；F-08）。
final inspectorRouteActiveProvider =
    NotifierProvider<InspectorRouteActiveNotifier, bool>(
        InspectorRouteActiveNotifier.new);

class InspectorRouteActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// kalender 事件控制器（视图装载 occurrence 的桥；测试可 override 注入）。
final kalenderEventsControllerProvider =
    Provider<kalender.DefaultEventsController>((ref) {
  return kalender.DefaultEventsController();
});

/// 契约 §8.1 Apple 7 预设色（#RRGGBB；节假日默认红 #FF3B30 见 S-09）。
const List<(String, int)> kCalendarPresetColors = [
  ('红', 0xFFFF3B30),
  ('橙', 0xFFFF9500),
  ('黄', 0xFFFFCC00),
  ('绿', 0xFF34C759),
  ('蓝', 0xFF007AFF),
  ('紫', 0xFFAF52DE),
  ('棕', 0xFFA2845E),
];

/// 侧栏显隐偏好存储（组合根注入 SharedPreferences；键契约：lifeos.calendar.sidebar.visible）。
final sidebarPrefsProvider = Provider<dynamic>((ref) {
  // dynamic 规避 feature_calendar 对宿主偏好实现的耦合；组合根注入 SharedPreferences。
  return null;
});

/// 侧栏显隐（medium/expanded 档；☰ 切换，shared_preferences 持久化）。
final sidebarVisibleProvider =
    NotifierProvider<SidebarVisibleNotifier, bool>(SidebarVisibleNotifier.new);

class SidebarVisibleNotifier extends Notifier<bool> {
  static const _key = 'lifeos.calendar.sidebar.visible';

  @override
  bool build() {
    final prefs = ref.watch(sidebarPrefsProvider);
    if (prefs == null) {
      return true;
    }
    return prefs.getBool(_key) ?? true;
  }

  void set(bool value) {
    state = value;
    final prefs = ref.watch(sidebarPrefsProvider);
    prefs?.setBool(_key, value);
  }

  void toggle() => set(!state);
}
