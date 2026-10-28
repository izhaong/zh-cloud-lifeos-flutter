import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show SingleActivator, ShortcutActivator;
import 'package:flutter_test/flutter_test.dart';

/// TC-CAL-UI-503 / 契约 §8.4：**快捷键映射表**必须完整。
///
/// widget 测试模拟不了 meta 组合键，所以键位的端到端行为只能手动验；但「有没有
/// 绑上、绑到哪个 Intent」是纯数据，必须机器校验——否则矩阵 L1「快捷键 38 条
/// 对等」就只是一句没人查的话（上一张引用校验器展开 `TC-CAL-UI-503~520` 时发现
/// 18 条全是占位）。
void main() {
  final mod = calendarShortcutBindings();
  final bare = calendarUnmodifiedShortcutBindings();
  final sidebar = sidebarShortcutBindings();

  test('修饰键表：逐条断言契约 §8.4 的键位绑到预期 Intent', () {
    expect(mod.length, 21, reason: '绑定数量变化必须同步改本测试与契约 §8.4');

    final expected = <ShortcutActivator, Type>{
      const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
          NextPeriodIntent,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
          PrevPeriodIntent,
      const SingleActivator(LogicalKeyboardKey.keyT, meta: true): TodayIntent,
      const SingleActivator(LogicalKeyboardKey.keyT, meta: true, shift: true):
          JumpToDateIntent,
      const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
          SetViewModeIntent,
      const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
          SetViewModeIntent,
      const SingleActivator(LogicalKeyboardKey.digit3, meta: true):
          SetViewModeIntent,
      const SingleActivator(LogicalKeyboardKey.digit4, meta: true):
          SetViewModeIntent,
      const SingleActivator(LogicalKeyboardKey.keyR, meta: true): RefreshIntent,
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
          NewEventIntent,
      const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
          EditSelectedIntent,
      const SingleActivator(LogicalKeyboardKey.keyI, meta: true, alt: true):
          OpenInspectorWindowIntent,
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
          FocusSearchIntent,
      const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
          ShowInfoIntent,
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
          NewCalendarGroupIntent,
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true, alt: true):
          NewSubscriptionIntent,
      const SingleActivator(LogicalKeyboardKey.arrowUp,
          control: true, alt: true): MoveSelectionIntent,
      const SingleActivator(LogicalKeyboardKey.arrowDown,
          control: true, alt: true): MoveSelectionIntent,
      const SingleActivator(LogicalKeyboardKey.arrowRight,
          control: true, alt: true): MoveSelectionIntent,
      const SingleActivator(LogicalKeyboardKey.arrowLeft,
          control: true, alt: true): MoveSelectionIntent,
      const SingleActivator(LogicalKeyboardKey.comma, meta: true):
          OpenSettingsIntent,
    };

    for (final e in expected.entries) {
      expect(mod.containsKey(e.key), isTrue, reason: '缺少绑定：${e.key}');
      expect(
        mod[e.key].runtimeType,
        e.value,
        reason: '$e.key 应绑到 ${e.value}',
      );
    }
    expect(mod.length, expected.length, reason: '不得有契约外的多余绑定');
  });

  test('⌘1~4 分别切日/周/月/年（同一 Intent、不同载荷）', () {
    final modes = <int, CalendarViewMode>{
      LogicalKeyboardKey.digit1.keyId: CalendarViewMode.day,
      LogicalKeyboardKey.digit2.keyId: CalendarViewMode.week,
      LogicalKeyboardKey.digit3.keyId: CalendarViewMode.month,
      LogicalKeyboardKey.digit4.keyId: CalendarViewMode.year,
    };
    for (final activator in mod.keys.whereType<SingleActivator>()) {
      final mode = modes[activator.trigger.keyId];
      if (mode == null) continue;
      expect((mod[activator]! as SetViewModeIntent).mode, mode,
          reason: '${activator.trigger.keyLabel} 应切到 $mode');
    }
  });

  test('⌃⌥方向键的移动量：↑+15 分 / ↓-15 分 / →+1 天 / ←-1 天', () {
    final expected = <LogicalKeyboardKey, Duration>{
      LogicalKeyboardKey.arrowUp: const Duration(minutes: 15),
      LogicalKeyboardKey.arrowDown: const Duration(minutes: -15),
      LogicalKeyboardKey.arrowRight: const Duration(days: 1),
      LogicalKeyboardKey.arrowLeft: const Duration(days: -1),
    };
    var checked = 0;
    for (final activator in mod.keys.whereType<SingleActivator>()) {
      // 必须同时是 ⌃⌥：只看 trigger 会把 ⌘→（NextPeriod）也算进来
      if (!activator.control || !activator.alt) continue;
      final delta = expected[activator.trigger];
      if (delta == null) continue;
      expect((mod[activator]! as MoveSelectionIntent).delta, delta);
      checked++;
    }
    expect(checked, 4, reason: '四个 ⌃⌥ 方向键都要在表里');
  });

  test('裸键（Delete/Esc/Return）只挂在独立表里，不进全局表', () {
    expect(bare.length, 3);
    expect(
      bare[const SingleActivator(LogicalKeyboardKey.delete)].runtimeType,
      DeleteSelectedIntent,
    );
    expect(
      bare[const SingleActivator(LogicalKeyboardKey.escape)].runtimeType,
      CloseEditingIntent,
    );
    expect(
      bare[const SingleActivator(LogicalKeyboardKey.enter)].runtimeType,
      CloseEditingIntent,
    );
    // 全局表里不得出现裸键（否则会吞掉文本框输入）
    for (final activator in mod.keys.whereType<SingleActivator>()) {
      expect(
        activator.meta || activator.control || activator.alt,
        isTrue,
        reason: '${activator.trigger.keyLabel} 没有修饰键，不该在全局表里',
      );
    }
  });

  test('侧栏 Space 切显隐（仅侧栏焦点内）', () {
    expect(sidebar.length, 1);
    expect(
      sidebar[const SingleActivator(LogicalKeyboardKey.space)].runtimeType,
      ToggleCalendarVisibilityIntent,
    );
  });
}
