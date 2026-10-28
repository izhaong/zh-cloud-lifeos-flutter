import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:app_core/app_core.dart';

import 'logic/event_time.dart';
import 'providers.dart';

/// 日/周视图回调接线（F-05；TC-CAL-UI-130/135/139 的可测核心）。
///
/// widget 层把 kalender 手势翻译到本类；仓库写入只发生在
/// [onEventMoved]（拖动/改尺寸松手），草稿只进 [draftEventProvider] 不落库。
class CalendarViewCallbacks {
  CalendarViewCallbacks({
    required this.repo,
    required this.preference,
    required this.setDraft,
    this.openOccurrence,
    this.reminderRepository,
    this.timeZone = 'UTC',
  });

  final CalendarRepository repo;
  final CalendarPreference preference;

  /// 设备/显示时区（IANA）。草稿必须带它：此前硬编码 'UTC'，全天归一
  /// 会锚到 UTC 零点，在 UTC−4 等时区渲染成前一天（parity#219）。
  final String timeZone;

  /// 提醒事项仓库（F-15 投影的完成/删除；null = 只读展示）。
  final ReminderRepository? reminderRepository;

  /// 草稿落位（scaffold 注入 draftEventProvider 写入）。
  final void Function(CalendarEvent draft) setDraft;

  /// 由 occurrence 打开 Inspector（草稿 + 该次原始开始；F-10 作用域用）。
  final void Function(CalendarEvent draft, DateTime occurrenceStart)?
  openOccurrence;

  /// 点已有 occurrence：
  /// - reminder → 切换完成（空心圆，TC-CAL-UI-192）
  /// - event → 取主记录（含 rrule）后打开 Inspector
  Future<void> onOccurrenceTapped(CalendarOccurrence occurrence) async {
    if (occurrence.source == OccurrenceSource.reminder) {
      final id = occurrence.reminderId;
      if (id != null) {
        await reminderRepository?.toggleCompleted(id);
      }
      return;
    }
    if (openOccurrence == null) {
      return;
    }
    final master =
        await repo.getEvent(occurrence.masterEventId) ??
        await repo.getEvent(occurrence.eventId);
    if (master != null) {
      openOccurrence!(master, occurrence.start);
    }
  }

  /// 删除提醒（走任务删除而非日历事件删除；TC-CAL-UI-193）。
  Future<void> deleteReminderOccurrence(CalendarOccurrence occurrence) async {
    final id = occurrence.reminderId;
    if (id != null) {
      await reminderRepository?.deleteItem(id);
    }
  }

  /// TC-CAL-UI-130：双击/拖选创建 → 草稿（时长=偏好默认；标题空不落库）。
  CalendarEvent onDraftCreate(DateTime start, DateTime end) {
    // #294：拖拽创建要用**拖出来的长度**（Apple：10:00 拖到 12:00 就是两小时）；
    // 只有双击那种「零长度」调用才回落默认时长（`double_tap_create` 传
    // start==end，TC-CAL-UI-130）。
    final dragged = end.isAfter(start) ? end.difference(start) : Duration.zero;
    final duration = dragged > Duration.zero
        ? dragged
        : Duration(minutes: preference.defaultDurationMinutes);
    final draft = withTimes(
      _emptyDraft(),
      start.toUtc(),
      start.toUtc().add(duration),
    );
    setDraft(draft);
    return draft;
  }

  /// 是否为「全天区拖拽」区间（parity#228）。
  ///
  /// kalender 0.33 的 `createNewEvent` 一律构造 `KalenderEvent(start,end)`，
  /// **不带 isAllDay**，所以不能靠 `event.isAllDay` 判断落在哪个泳道。
  /// 全天区的拖拽区间按天对齐（两端都是 00:00，且跨度 ≥1 天），时间轴拖拽
  /// 则带分钟粒度：据此区分。
  static bool looksLikeAllDayRange(DateTime start, DateTime end) {
    final alignedStart = start.hour == 0 && start.minute == 0;
    final alignedEnd = end.hour == 0 && end.minute == 0;
    return alignedStart && alignedEnd && !end.isBefore(start.add(const Duration(days: 1)));
  }

  /// #240：拖选是否跨了多个**本地日**（周视图横向拖过列边界即算）。
  static bool spansMultipleDays(DateTime start, DateTime end) {
    return DateTime(end.year, end.month, end.day)
        .isAfter(DateTime(start.year, start.month, start.day));
  }

  /// #240：多日拖选的**排他终点**。
  ///
  /// Apple：拖进周三即周三也在所选范围内，但草稿 endAt 是排他边界，所以
  /// 终点非零点时要补到次日零点。终点正好落在零点时不补（否则多算一天）。
  static DateTime inclusiveAllDayEnd(DateTime end) {
    final endDay = DateTime(end.year, end.month, end.day);
    final atMidnight = end.hour == 0 && end.minute == 0 && end.second == 0;
    return atMidnight ? endDay : endDay.add(const Duration(days: 1));
  }

  /// 拖拽创建分派（#240；两个视图的 onEventCreate 都走这里）。
  ///
  /// - 全天区拖选（两端零点且跨天）→ 全天草稿，保留拖选终点（parity#228）；
  /// - 定时网格里跨多日横拖 → 覆盖所选日期的**多日全天**草稿（Apple 周视图
  ///   语义，矩阵 E2）；此前这里按「起始 + 偏好默认时长」造 1 小时，把终点丢了；
  /// - 同日内拖选 → 仍按 TC-CAL-UI-130「时长=偏好默认」。
  CalendarEvent onDragCreate(DateTime startLocal, DateTime endLocal) {
    // 全天带的拖选**从某日零点起**（kalender 的「天」行），终点可能带 01:00
    // 这类时刻（#228 记载）：这条路径保持「按日截断」语义，不能按包含补天，
    // 否则同一次拖拽会比 #228 多算一天。
    if (startLocal.hour == 0 &&
        startLocal.minute == 0 &&
        startLocal.second == 0 &&
        spansMultipleDays(startLocal, endLocal)) {
      return onAllDayDraftCreate(startLocal, endLocal);
    }
    // 定时网格里横拖跨多日：起点带时刻，按 Apple「拖进哪天就含哪天」补到次日零点。
    if (spansMultipleDays(startLocal, endLocal)) {
      return onAllDayDraftCreate(startLocal, inclusiveAllDayEnd(endLocal));
    }
    return onDraftCreate(startLocal.toUtc(), endLocal.toUtc());
  }

  /// TC-CAL-UI-139 / E2：全天区拖多日 → 跨天全天草稿。
  ///
  /// kalender 的 `onEventCreate` 对「全天区」拖拽给的是 isAllDay 事件，
  /// 但区间可能带 00:00–01:00 之类的时刻；这里按**日期**归一成
  /// 当地 00:00 → 次日 00:00（排他），丢掉时刻（parity#228）。
  CalendarEvent onAllDayDraftCreate(DateTime start, DateTime end) {
    final startDay = DateTime(start.year, start.month, start.day);
    var endDay = DateTime(end.year, end.month, end.day);
    if (!endDay.isAfter(startDay)) {
      endDay = startDay.add(const Duration(days: 1));
    }
    final draft = CalendarEvent(
      id: 'draft',
      calendarId: '',
      uid: '',
      title: '',
      startAt: utcFromWall(startDay, timeZone),
      endAt: utcFromWall(endDay, timeZone),
      allDay: true,
      timeZone: timeZone,
      updatedAt: DateTime.now().toUtc(),
    );
    setDraft(draft);
    return draft;
  }

  /// TC-CAL-UI-131：月视图点/双击某日 → 全天草稿（标题空）。
  void onDayTap(DateTime date) {
    // 用设备时区的当地 00:00 → 次日 00:00（排他），再转 UTC；
    // 写 UTC 零点会在西半球时区把「今天」渲染成前一天（parity#219）。
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day + 1);
    setDraft(
      CalendarEvent(
        id: 'draft',
        calendarId: '',
        uid: '',
        title: '',
        startAt: utcFromWall(dayStart, timeZone),
        endAt: utcFromWall(dayEnd, timeZone),
        allDay: true,
        timeZone: timeZone,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// TC-CAL-UI-135：拖动改时间 → 仓库 startAt 变化。
  /// TC-CAL-UI-139：全天行拖多日 → end 排他（周四 00:00）。
  Future<void> onEventMoved(
    CalendarEvent event,
    DateTime newStart,
    DateTime newEnd,
  ) async {
    await repo.upsertEvent(withTimes(event, newStart.toUtc(), newEnd.toUtc()));
  }

  CalendarEvent _emptyDraft() {
    return CalendarEvent(
      id: 'draft',
      calendarId: '',
      uid: '',
      title: '',
      startAt: DateTime.now().toUtc(),
      endAt: DateTime.now().toUtc(),
      timeZone: timeZone,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}

/// 全字段拷贝改起止（kernel 模型无 copyWith）。
CalendarEvent withTimes(CalendarEvent e, DateTime start, DateTime end) {
  return CalendarEvent(
    id: e.id,
    remoteId: e.remoteId,
    calendarId: e.calendarId,
    uid: e.uid,
    title: e.title,
    location: e.location,
    url: e.url,
    notes: e.notes,
    startAt: start,
    endAt: end,
    allDay: e.allDay,
    timeZone: e.timeZone,
    isFloating: e.isFloating,
    rrule: e.rrule,
    exdates: e.exdates,
    parentEventId: e.parentEventId,
    originalStartAt: e.originalStartAt,
    status: e.status,
    availability: e.availability,
    travelMinutes: e.travelMinutes,
    isPrivate: e.isPrivate,
    alerts: e.alerts,
    invitees: e.invitees,
    sequence: e.sequence,
    revision: e.revision,
    deletedAt: e.deletedAt,
    updatedAt: e.updatedAt,
  );
}

/// 由偏好派生的视图配置（纯数据；TC-CAL-UI-105/106 断言口径）。
class CalendarViewConfigs {
  const CalendarViewConfigs({required this.day, required this.week});

  final DayViewConfig day;
  final WeekViewConfig week;
}

class DayViewConfig {
  const DayViewConfig({required this.startHour, required this.endHour});

  /// 日视图起始/结束小时（TC-CAL-UI-106）。
  final int startHour;
  final int endHour;
}

class WeekViewConfig {
  const WeekViewConfig({required this.numberOfDays, required this.isWorkWeek});

  /// 周显示天数（7=week、5=workWeek，TC-CAL-UI-102/105）。
  final int numberOfDays;

  /// workWeek 口径（不含周六日）。
  final bool isWorkWeek;
}

/// 偏好 → 视图配置（契约 §8.3/§8.5）。
final calendarViewConfigurationsProvider = Provider<CalendarViewConfigs>((ref) {
  final preference =
      ref.watch(preferenceProvider).value ?? CalendarPreference.defaults;
  return CalendarViewConfigs(
    day: DayViewConfig(
      startHour: preference.dayStartHour,
      endHour: preference.dayEndHour,
    ),
    week: WeekViewConfig(
      numberOfDays: preference.weekViewDays,
      isWorkWeek: preference.weekViewDays == 5,
    ),
  );
});

/// 双击/拖选创建的草稿（F-08 Inspector 接管保存；标题空不落库）。
final draftEventProvider = NotifierProvider<DraftEventNotifier, CalendarEvent?>(
  DraftEventNotifier.new,
);

class DraftEventNotifier extends Notifier<CalendarEvent?> {
  @override
  CalendarEvent? build() => null;

  void setDraft(CalendarEvent draft) {
    state = draft;
  }

  void clear() => state = null;
}

/// 删除提醒前确认（走提醒事项删除，不进日历事件删除；TC-CAL-UI-193）。
Future<void> confirmDeleteReminder(
  BuildContext context,
  CalendarViewCallbacks callbacks,
  CalendarOccurrence occurrence,
) async {
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => LifeAlertDialog(
      key: const Key('reminder_delete_dialog'),
      title: const Text('删除提醒'),
      content: Text('「${occurrence.title}」将移到提醒事项的最近删除。'),
      actions: [
        LifeDialogAction(
          key: const Key('reminder_delete_cancel'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        LifeDialogAction(
          key: const Key('reminder_delete_confirm'),
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await callbacks.deleteReminderOccurrence(occurrence);
  }
}
