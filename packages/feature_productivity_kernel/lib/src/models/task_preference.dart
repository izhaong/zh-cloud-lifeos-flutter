import 'dart:convert';

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
    this.todayNotifyTime = '09:00',
    this.manualTimeZone,
    this.showCompleted = false,
    this.sortMode = 'manual',
    this.sidebarVisible = true,
    this.collapsedKeys = const [],
    this.viewOptionsJson = '{}',
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

  /// 手动设定的时区（#448）：IANA 名（如 `Asia/Shanghai`），null = 跟随系统。
  ///
  /// 消费者是 `effectiveNow()`——全仓「今天/逾期」判定的唯一入口。
  final String? manualTimeZone;

  /// 「今天」汇总通知时点（#445）：`HH:mm` 字符串，默认 `09:00`。
  ///
  /// 用字符串而不是 `DateTime`：这是**每日重复**的墙钟时刻，没有日期语义；
  /// 存 DateTime 会让「今天 09:00」这类值随日期漂移。
  final String todayNotifyTime;

  /// 解析成 (时, 分)；非法值回落到 09:00（设置坏掉不该让通知消失）。
  (int, int) get todayNotifyHourMinute {
    final parts = todayNotifyTime.split(':');
    if (parts.length != 2) return (9, 0);
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return (9, 0);
    }
    return (h, m);
  }

  /// 列表内「显示已完成」（TC-UI-108 默认 false）。
  final bool showCompleted;

  /// 排序模式名（`manual`/`dueDate`/`title`/`priority`；未知串按 manual 处理）。
  final String sortMode;

  /// 提醒侧栏显隐（TC-UI-304）。
  final bool sidebarVisible;

  /// 折叠态键：`'<listId>|<分区标题>'` 与 `'group:<分组名>''`（TC-UI-309）。
  final List<String> collapsedKeys;

  /// 通用视图开关（#574 起）：JSON 对象字符串，避免每个菜单级视图开关都加一列。
  /// 目前键：`groupByTime`（#574）、`viewMode`（#573，`list`/`columns`）。
  final String viewOptionsJson;

  /// 读一个布尔视图开关；坏 JSON / 缺键按 [fallback]。
  bool viewOptionBool(String key, {bool fallback = false}) {
    try {
      final decoded = jsonDecode(viewOptionsJson);
      if (decoded is Map && decoded[key] is bool) {
        return decoded[key] as bool;
      }
    } catch (_) {
      // 坏 JSON 不影响数据可用，按默认值处理。
    }
    return fallback;
  }

  /// 写一个布尔视图开关，保留其它键。
  TaskPreference withViewOptionBool(String key, bool value) {
    final map = <String, Object?>{};
    try {
      final decoded = jsonDecode(viewOptionsJson);
      if (decoded is Map) {
        decoded.forEach((k, v) => map['$k'] = v);
      }
    } catch (_) {
      // 坏 JSON 直接重建。
    }
    map[key] = value;
    return copyWith(viewOptionsJson: jsonEncode(map));
  }

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
    String? todayNotifyTime,
    String? manualTimeZone,
    bool clearManualTimeZone = false,
    bool? showCompleted,
    String? sortMode,
    bool? sidebarVisible,
    List<String>? collapsedKeys,
    String? viewOptionsJson,
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
      todayNotifyTime: todayNotifyTime ?? this.todayNotifyTime,
      manualTimeZone: clearManualTimeZone
          ? null
          : (manualTimeZone ?? this.manualTimeZone),
      showCompleted: showCompleted ?? this.showCompleted,
      sortMode: sortMode ?? this.sortMode,
      sidebarVisible: sidebarVisible ?? this.sidebarVisible,
      collapsedKeys: collapsedKeys ?? this.collapsedKeys,
      viewOptionsJson: viewOptionsJson ?? this.viewOptionsJson,
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
        todayNotifyTime,
        manualTimeZone,
        showCompleted,
        sortMode,
        sidebarVisible,
        collapsedKeys,
        viewOptionsJson,
        revision,
      ];
}
