import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// 任务侧本地偏好（TC-UI-120 / TC-UI-308 / TC-UI-309；一用户一行，
/// 照 lifeos/calendar 的 CalendarPreference 先例）。
///
/// 上半是设置弹层（图1）四档：默认列表 / 全天提醒时点 / 完成时标记为已完成 / 建议列表；
/// 下半是视图态：显示已完成 / 排序模式 / 侧栏显隐 / 分区与分组折叠键。
/// 「还原」= 写回 [TaskPreference.defaults]（`revision` 由实现层接管，调用方传什么都无所谓）。
@immutable
final class TaskPreference extends Equatable {
  const TaskPreference({
    this.defaultListId,
    this.allDayNotify = true,
    this.markComplete = false,
    this.suggestLists = true,
    this.badgeIncludesTodayDue = true,
    this.allDayRemindersOverdue = false,
    this.showCompleted = false,
    this.sortMode = 'manual',
    this.sidebarVisible = true,
    this.collapsedKeys = const [],
    this.revision = 1,
  });

  /// 新建提醒的默认列表（null = 未设置，落「首个自有列表」）。
  final String? defaultListId;

  /// 全天提醒时点（开关：全天事项是否按默认时点提醒）。
  final bool allDayNotify;

  /// 完成时标记为已完成（子任务全完成时父项是否自动打勾）。
  final bool markComplete;

  /// 建议列表（新建时是否弹出智能列表建议）。
  final bool suggestLists;

  /// 徽标数量是否包含「今天到期」（#451）。
  final bool badgeIncludesTodayDue;

  /// 全天提醒是否按「逾期」显示（#446；默认 false = 与改造前行为一致）。
  final bool allDayRemindersOverdue;

  /// 列表内「显示已完成」（TC-UI-108 默认 false）。
  final bool showCompleted;

  /// 排序模式名（`manual`/`dueDate`/`title`/`priority`；未知串按 manual 处理）。
  final String sortMode;

  /// 提醒侧栏显隐（TC-UI-304）。
  final bool sidebarVisible;

  /// 折叠态键：`'<listId>|<分区标题>'` 与 `'group:<分组名>''`（TC-UI-309）。
  final List<String> collapsedKeys;

  /// 保存次数（每次保存 +1，与日历偏好同口径）。
  final int revision;

  /// 契约默认值（无行时实现层回这个值，不写库）。
  static const TaskPreference defaults = TaskPreference();

  TaskPreference copyWith({
    String? defaultListId,
    bool clearDefaultListId = false,
    bool? allDayNotify,
    bool? markComplete,
    bool? suggestLists,
    bool? badgeIncludesTodayDue,
    bool? allDayRemindersOverdue,
    bool? showCompleted,
    String? sortMode,
    bool? sidebarVisible,
    List<String>? collapsedKeys,
    int? revision,
  }) {
    return TaskPreference(
      // 泛型/空值语义要显式：`clearDefaultListId` 是「置为未设置」的唯一通道，
      // 不能靠 defaultListId==null 区分「没传」与「要清空」。
      defaultListId:
          clearDefaultListId ? null : (defaultListId ?? this.defaultListId),
      allDayNotify: allDayNotify ?? this.allDayNotify,
      markComplete: markComplete ?? this.markComplete,
      suggestLists: suggestLists ?? this.suggestLists,
      badgeIncludesTodayDue:
          badgeIncludesTodayDue ?? this.badgeIncludesTodayDue,
      allDayRemindersOverdue:
          allDayRemindersOverdue ?? this.allDayRemindersOverdue,
      showCompleted: showCompleted ?? this.showCompleted,
      sortMode: sortMode ?? this.sortMode,
      sidebarVisible: sidebarVisible ?? this.sidebarVisible,
      collapsedKeys: collapsedKeys ?? this.collapsedKeys,
      revision: revision ?? this.revision,
    );
  }

  @override
  List<Object?> get props => [
        defaultListId,
        allDayNotify,
        markComplete,
        suggestLists,
        badgeIncludesTodayDue,
        allDayRemindersOverdue,
        showCompleted,
        sortMode,
        sidebarVisible,
        collapsedKeys,
        revision,
      ];
}
