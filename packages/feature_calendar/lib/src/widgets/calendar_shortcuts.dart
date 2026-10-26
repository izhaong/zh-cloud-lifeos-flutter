/// 日历快捷键绑定表（契约 §8.4；F-13）。
///
/// 带修饰键的组合放在全局 [calendarShortcutBindings]；
/// 裸键（Space/Delete/Esc/Return）会吞掉文本输入，只挂在日历主视图/侧栏内。
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../providers.dart';

// ---- Intent ----

class NextPeriodIntent extends Intent {
  const NextPeriodIntent();
}

class PrevPeriodIntent extends Intent {
  const PrevPeriodIntent();
}

class TodayIntent extends Intent {
  const TodayIntent();
}

class JumpToDateIntent extends Intent {
  const JumpToDateIntent();
}

class SetViewModeIntent extends Intent {
  const SetViewModeIntent(this.mode);

  final CalendarViewMode mode;
}

class RefreshIntent extends Intent {
  const RefreshIntent();
}

class NewEventIntent extends Intent {
  const NewEventIntent();
}

class EditSelectedIntent extends Intent {
  const EditSelectedIntent();
}

class OpenInspectorWindowIntent extends Intent {
  const OpenInspectorWindowIntent();
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class ShowInfoIntent extends Intent {
  const ShowInfoIntent();
}

class NewCalendarGroupIntent extends Intent {
  const NewCalendarGroupIntent();
}

class NewSubscriptionIntent extends Intent {
  const NewSubscriptionIntent();
}

class MoveSelectionIntent extends Intent {
  const MoveSelectionIntent(this.delta);

  final Duration delta;
}

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class DeleteSelectedIntent extends Intent {
  const DeleteSelectedIntent();
}

class CloseEditingIntent extends Intent {
  const CloseEditingIntent();
}

class ToggleCalendarVisibilityIntent extends Intent {
  const ToggleCalendarVisibilityIntent();
}

// ---- 绑定表 ----

/// 带修饰键的全局快捷键（契约 §8.4）。
Map<ShortcutActivator, Intent> calendarShortcutBindings() {
  return {
    const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
        const NextPeriodIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
        const PrevPeriodIntent(),
    const SingleActivator(LogicalKeyboardKey.keyT, meta: true):
        const TodayIntent(),
    const SingleActivator(LogicalKeyboardKey.keyT, meta: true, shift: true):
        const JumpToDateIntent(),
    const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
        const SetViewModeIntent(CalendarViewMode.day),
    const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
        const SetViewModeIntent(CalendarViewMode.week),
    const SingleActivator(LogicalKeyboardKey.digit3, meta: true):
        const SetViewModeIntent(CalendarViewMode.month),
    const SingleActivator(LogicalKeyboardKey.digit4, meta: true):
        const SetViewModeIntent(CalendarViewMode.year),
    const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
        const RefreshIntent(),
    const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
        const NewEventIntent(),
    const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
        const EditSelectedIntent(),
    const SingleActivator(LogicalKeyboardKey.keyI, meta: true, alt: true):
        const OpenInspectorWindowIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
        const FocusSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
        const ShowInfoIntent(),
    const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
        const NewCalendarGroupIntent(),
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true, alt: true):
        const NewSubscriptionIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowUp,
        control: true, alt: true): const MoveSelectionIntent(
        Duration(minutes: 15)),
    const SingleActivator(LogicalKeyboardKey.arrowDown,
        control: true, alt: true): const MoveSelectionIntent(
        Duration(minutes: -15)),
    const SingleActivator(LogicalKeyboardKey.arrowRight,
        control: true, alt: true): const MoveSelectionIntent(
        Duration(days: 1)),
    const SingleActivator(LogicalKeyboardKey.arrowLeft,
        control: true, alt: true): const MoveSelectionIntent(
        Duration(days: -1)),
    const SingleActivator(LogicalKeyboardKey.comma, meta: true):
        const OpenSettingsIntent(),
  };
}

/// 裸键（只在日历主视图/侧栏焦点内生效，避免吞文本框输入）。
Map<ShortcutActivator, Intent> calendarUnmodifiedShortcutBindings() {
  return {
    const SingleActivator(LogicalKeyboardKey.delete):
        const DeleteSelectedIntent(),
    const SingleActivator(LogicalKeyboardKey.escape):
        const CloseEditingIntent(),
    const SingleActivator(LogicalKeyboardKey.enter):
        const CloseEditingIntent(),
  };
}

/// 侧栏：Space 勾选/取消选中日历（契约 §8.4）。
Map<ShortcutActivator, Intent> sidebarShortcutBindings() {
  return {
    const SingleActivator(LogicalKeyboardKey.space):
        const ToggleCalendarVisibilityIntent(),
  };
}

/// 把快捷键表接到一组回调（scaffold 注入）。
class CalendarShortcutActions extends StatelessWidget {
  const CalendarShortcutActions({
    super.key,
    required this.child,
    this.onNextPeriod,
    this.onPrevPeriod,
    this.onToday,
    this.onJumpToDate,
    this.onSetViewMode,
    this.onRefresh,
    this.onNewEvent,
    this.onEditSelected,
    this.onOpenInspectorWindow,
    this.onFocusSearch,
    this.onShowInfo,
    this.onNewCalendarGroup,
    this.onNewSubscription,
    this.onMoveSelection,
    this.onSettings,
    this.onDeleteSelected,
    this.onCloseEditing,
    this.onToggleCalendarVisibility,
  });

  final Widget child;
  final VoidCallback? onNextPeriod;
  final VoidCallback? onPrevPeriod;
  final VoidCallback? onToday;
  final VoidCallback? onJumpToDate;
  final ValueChanged<CalendarViewMode>? onSetViewMode;
  final VoidCallback? onRefresh;
  final VoidCallback? onNewEvent;
  final VoidCallback? onEditSelected;
  final VoidCallback? onOpenInspectorWindow;
  final VoidCallback? onFocusSearch;
  final VoidCallback? onShowInfo;
  final VoidCallback? onNewCalendarGroup;
  final VoidCallback? onNewSubscription;
  final ValueChanged<Duration>? onMoveSelection;
  final VoidCallback? onSettings;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onCloseEditing;
  final VoidCallback? onToggleCalendarVisibility;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: calendarShortcutBindings(),
      child: Actions(
        actions: {
          NextPeriodIntent: CallbackAction<NextPeriodIntent>(
              onInvoke: (_) => onNextPeriod?.call()),
          PrevPeriodIntent: CallbackAction<PrevPeriodIntent>(
              onInvoke: (_) => onPrevPeriod?.call()),
          TodayIntent: CallbackAction<TodayIntent>(
              onInvoke: (_) => onToday?.call()),
          JumpToDateIntent: CallbackAction<JumpToDateIntent>(
              onInvoke: (_) => onJumpToDate?.call()),
          SetViewModeIntent: CallbackAction<SetViewModeIntent>(
              onInvoke: (i) => onSetViewMode?.call(i.mode)),
          RefreshIntent: CallbackAction<RefreshIntent>(
              onInvoke: (_) => onRefresh?.call()),
          NewEventIntent: CallbackAction<NewEventIntent>(
              onInvoke: (_) => onNewEvent?.call()),
          EditSelectedIntent: CallbackAction<EditSelectedIntent>(
              onInvoke: (_) => onEditSelected?.call()),
          OpenInspectorWindowIntent: CallbackAction<OpenInspectorWindowIntent>(
              onInvoke: (_) => onOpenInspectorWindow?.call()),
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(
              onInvoke: (_) => onFocusSearch?.call()),
          ShowInfoIntent: CallbackAction<ShowInfoIntent>(
              onInvoke: (_) => onShowInfo?.call()),
          NewCalendarGroupIntent: CallbackAction<NewCalendarGroupIntent>(
              onInvoke: (_) => onNewCalendarGroup?.call()),
          NewSubscriptionIntent: CallbackAction<NewSubscriptionIntent>(
              onInvoke: (_) => onNewSubscription?.call()),
          MoveSelectionIntent: CallbackAction<MoveSelectionIntent>(
              onInvoke: (i) => onMoveSelection?.call(i.delta)),
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
              onInvoke: (_) => onSettings?.call()),
          DeleteSelectedIntent: CallbackAction<DeleteSelectedIntent>(
              onInvoke: (_) => onDeleteSelected?.call()),
          CloseEditingIntent: CallbackAction<CloseEditingIntent>(
              onInvoke: (_) => onCloseEditing?.call()),
          ToggleCalendarVisibilityIntent:
              CallbackAction<ToggleCalendarVisibilityIntent>(
                  onInvoke: (_) => onToggleCalendarVisibility?.call()),
        },
        child: child,
      ),
    );
  }
}
