import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

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
    final duration = Duration(minutes: preference.defaultDurationMinutes);
    final draft = withTimes(
      _emptyDraft(),
      start.toUtc(),
      start.toUtc().add(duration),
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
    builder: (ctx) => CupertinoAlertDialog(
      key: const Key('reminder_delete_dialog'),
      title: const Text('删除提醒'),
      content: Text('「${occurrence.title}」将移到提醒事项的最近删除。'),
      actions: [
        CupertinoDialogAction(
          key: const Key('reminder_delete_cancel'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
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
