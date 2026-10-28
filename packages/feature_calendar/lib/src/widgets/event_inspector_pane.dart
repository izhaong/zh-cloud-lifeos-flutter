import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:app_core/app_core.dart';

import '../providers.dart';
import '../logic/event_time.dart';
import '../logic/calendar_ids.dart';
import '../alerts/calendar_alert_scheduler.dart';
import 'event_form_fields.dart'
    show EventFormFields, defaultCalendarOf, copyEventWithAlerts;

export '../logic/calendar_ids.dart' show kDraftEventId;

/// 日程 Inspector（契约 §5.4 event_inspector_pane.dart；F-08）。
///
/// 三档呈现由外壳决定（compact=全屏 push / medium=sheet / expanded=第三栏）——
/// 本组件只做布局无关的编辑面。保存走 `upsertEvent`；空标题禁止保存
/// （TC-CAL-UI-137：不关闭、不写库）。
class EventInspectorPane extends ConsumerStatefulWidget {
  const EventInspectorPane({
    super.key,
    required this.initialEvent,
    required this.onSaved,
    this.occurrenceStart,
    this.onDraftChanged,
    this.onClose,
    this.onDeleted,
  });

  final CalendarEvent initialEvent;

  /// 被编辑的 occurrence 原始开始（UTC）；重复事件 THIS/FUTURE 作用域用（F-10）。
  final DateTime? occurrenceStart;

  /// 保存成功回调（外壳用于关闭 sheet / 清 selectedOccurrence）。
  final VoidCallback onSaved;

  /// 删除成功回调（缺省回落到 [onSaved]）。
  final VoidCallback? onDeleted;

  /// 草稿变更回写（第三栏场景：断点降档卸栏后未保存修改不丢；可选）。
  final ValueChanged<CalendarEvent>? onDraftChanged;

  final VoidCallback? onClose;

  @override
  ConsumerState<EventInspectorPane> createState() => _EventInspectorPaneState();
}

class _EventInspectorPaneState extends ConsumerState<EventInspectorPane> {
  late CalendarEvent _draft;
  bool _saveAttempted = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialEvent;
  }

  @override
  void didUpdateWidget(covariant EventInspectorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ③ 新建草稿 id 恒为 kDraftEventId——按「实例变化」重置（连续双击也刷新）
    if (!identical(oldWidget.initialEvent, widget.initialEvent) &&
        oldWidget.initialEvent != widget.initialEvent) {
      _draft = widget.initialEvent;
      _saveAttempted = false;
    }
  }

  bool get _titleEmpty => _draft.title.trim().isEmpty;

  /// 保存受阻原因（标题空/日历缺失共用提示通道；空串=可保存）。
  String? _blockedReason;

  /// 草稿是否为「新建」（id 由创建入口统一用 [kDraftEventId]）。
  bool get _isNewDraft => _draft.id == kDraftEventId;

  bool _saving = false; // 在途互斥：连点保存不重复 upsert

  /// 重复事件编辑/删除的作用域选择（F-10 TC-CAL-UI-151/152）。
  Future<EditScope?> _askScope(String title) {
    return showCupertinoDialog<EditScope>(
      context: context,
      builder: (ctx) => LifeAlertDialog(
        key: const Key('repeat_scope_dialog'),
        title: Text(title),
        content: const Text('此日程属于重复系列，请选择改动范围。'),
        actions: [
          LifeDialogAction(
            key: const Key('scope_this'),
            onPressed: () => Navigator.of(ctx).pop(EditScope.thisOnly),
            child: const Text('仅此日程'),
          ),
          LifeDialogAction(
            key: const Key('scope_future'),
            onPressed: () => Navigator.of(ctx).pop(EditScope.thisAndFuture),
            child: const Text('此日程及之后'),
          ),
          LifeDialogAction(
            key: const Key('scope_all'),
            onPressed: () => Navigator.of(ctx).pop(EditScope.all),
            child: const Text('所有日程'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    if (_isNewDraft || _saving) {
      return;
    }
    final recurring = (widget.initialEvent.rrule ?? '').isNotEmpty;
    var scope = EditScope.all;
    if (recurring && widget.occurrenceStart != null) {
      final picked = await _askScope('删除重复日程');
      if (picked == null || !mounted) {
        return;
      }
      scope = picked;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(calendarRepositoryProvider)
          .deleteEvent(
            _draft.id,
            scope: scope,
            occurrenceStart: scope == EditScope.all
                ? null
                : widget.occurrenceStart,
          );
      await ref.read(calendarAlertSchedulerProvider).cancelEvent(_draft.id);
      if (mounted) {
        (widget.onDeleted ?? widget.onSaved)();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (_titleEmpty) {
      setState(() {
        _saveAttempted = true; // TC-CAL-UI-137：不关闭不写库
        _blockedReason = '请填写标题后再保存';
      });
      return;
    }
    // F-10：已有重复日程 → 先选作用域（仅此 / 及之后 / 所有）
    var scope = EditScope.all;
    final recurring = (widget.initialEvent.rrule ?? '').isNotEmpty;
    if (!_isNewDraft && recurring && widget.occurrenceStart != null) {
      final picked = await _askScope('编辑重复日程');
      if (picked == null || !mounted) {
        return;
      }
      scope = picked;
    }
    // ② 草稿日历为空时写回默认日历（否则空 calendarId 落库）
    var toSave = _draft;
    if (toSave.calendarId.isEmpty) {
      final asyncCalendars = ref.watch(calendarsProvider);
      final calendars = asyncCalendars.asData?.value ?? const <Calendar>[];
      final target = defaultCalendarOf(calendars);
      if (target == null) {
        // loading/无日历：明确提示而非静默失败
        setState(() {
          _saveAttempted = true;
          _blockedReason = asyncCalendars.isLoading
              ? '日历仍在加载，请稍候再保存'
              : '没有可用日历，无法保存';
        });
        return; // 不写库不关闭
      }
      toSave = _copyWithCalendar(toSave, target.id);
    }
    // ① 新建草稿：保存时生成新 id（多次创建互不覆盖）
    if (_isNewDraft) {
      toSave = _copyWithId(toSave, newCalendarEventId());
    }
    // F-09：保存前按 timeZone 归一全天（契约 §2.2；TC-CAL-KR-120）
    if (toSave.allDay) {
      toSave = normalizeAllDay(toSave);
    }
    // F-14：新草稿按偏好补默认提醒（TC-CAL-UI-212）
    if (_isNewDraft && toSave.alerts.isEmpty) {
      final pref = ref.read(preferenceProvider).value;
      if (pref != null) {
        if (toSave.allDay && pref.defaultAlertAllDayDays != null) {
          toSave = copyEventWithAlerts(toSave, [
            EventAlert(
              allDayOffsetDays: pref.defaultAlertAllDayDays,
              allDayTime: pref.defaultAlertAllDayTime,
            ),
          ]);
        } else if (!toSave.allDay && pref.defaultAlertTimedMinutes != null) {
          toSave = copyEventWithAlerts(toSave, [
            EventAlert(offsetMinutes: pref.defaultAlertTimedMinutes),
          ]);
        }
      }
    }
    final repo = ref.read(calendarRepositoryProvider);
    setState(() => _saving = true);
    try {
      await repo.upsertEvent(
        toSave,
        scope: scope,
        occurrenceStart: scope == EditScope.all ? null : widget.occurrenceStart,
      );
      await ref.read(calendarAlertSchedulerProvider).scheduleEvent(toSave);
      // 面板已被关闭（sheet/route pop）则不再触发 onSaved（防二次 pop）
      if (mounted) {
        widget.onSaved();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('event_inspector_pane'),
      child: Column(
        children: [
          _InspectorHeader(
            title: _draft.title.trim().isEmpty ? '新建日程' : _draft.title,
            showDelete: !_isNewDraft,
            onDelete: _delete,
            onSave: _save,
            onClose: widget.onClose,
          ),
          Expanded(
            child: EventFormFields(
              event: _draft,
              showTitleRequired: _saveAttempted,
              onChanged: (next) {
                setState(() => _draft = next);
                widget.onDraftChanged?.call(next);
              },
            ),
          ),
          if (_saveAttempted && _blockedReason != null)
            Padding(
              key: const Key('event_inspector_blocked_hint'),
              padding: const EdgeInsets.all(8),
              child: Text(
                _blockedReason!,
                style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// 三档呈现封装（外壳按宽度择一；契约 §8.5）。
///
/// compact <600 → 全屏 route；medium → bottom sheet；expanded ≥1200 → 第三栏 widget。
class EventInspectorHost extends StatelessWidget {
  const EventInspectorHost({
    super.key,
    required this.event,
    required this.onSaved,
    this.occurrenceStart,
  });

  final CalendarEvent event;
  final VoidCallback onSaved;
  final DateTime? occurrenceStart;

  /// compact 全屏（push 新路由；route 关闭即视为取消 → onDismissed）。
  static Future<void> openFullScreen(
    BuildContext context,
    CalendarEvent event,
    VoidCallback onSaved, {
    VoidCallback? onDismissed,
    DateTime? occurrenceStart,
  }) {
    // 关页必须用本路由自己的 context（resolve 到 push 它的那层 Navigator）。
    // 用外层 context 会落到壳分支 Navigator，pop 掉分支根页 → go_router
    // currentConfiguration.isNotEmpty 断言白屏（#154）。
    return Navigator.of(context)
        .push(
          CupertinoPageRoute<void>(
            builder: (routeContext) => CupertinoPageScaffold(
              child: SafeArea(
                child: EventInspectorPane(
                  initialEvent: event,
                  occurrenceStart: occurrenceStart,
                  onSaved: () {
                    onSaved();
                    Navigator.of(routeContext).pop();
                  },
                  onClose: () => Navigator.of(routeContext).pop(),
                ),
              ),
            ),
          ),
        )
        .then((_) => onDismissed?.call());
  }

  /// medium bottom sheet（sheet 关闭即视为取消 → onDismissed）。
  static Future<void> openSheet(
    BuildContext context,
    CalendarEvent event,
    VoidCallback onSaved, {
    VoidCallback? onDismissed,
    DateTime? occurrenceStart,
  }) {
    // 同上：sheet 由 rootNavigator 承载，关闭只能用 sheet 自己的 context，
    // 否则 pop 到壳分支根页 → 白屏（#154）。
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => SizedBox(
        // 用 sheet 自己的 context 读尺寸：外层 context 在页面重建/卸载后
        // 可能已 deactivated，查祖先会抛「deactivated widget's ancestor」。
        height: MediaQuery.sizeOf(sheetContext).height * 0.85,
        child: ColoredBox(
          color: CupertinoColors.systemBackground,
          child: EventInspectorPane(
            initialEvent: event,
            occurrenceStart: occurrenceStart,
            onSaved: () {
              onSaved();
              Navigator.of(sheetContext).pop();
            },
            onClose: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    ).then((_) => onDismissed?.call());
  }

  @override
  Widget build(BuildContext context) {
    // expanded 第三栏形态：外壳直接放进 Row 尾部。
    return EventInspectorPane(
      initialEvent: event,
      occurrenceStart: occurrenceStart,
      onSaved: onSaved,
      onClose: () {},
    );
  }
}

/// 日历事件 id 工厂（kernel 只提供 reminder/list 工厂；事件侧对齐命名）。
String newCalendarEventId() =>
    'cal_${DateTime.now().microsecondsSinceEpoch}_'
    '${_shortRand()}';

String _shortRand() {
  final r = DateTime.now().hashCode ^ identityHashCode(Object());
  return (r & 0xFFFFFF).toRadixString(36);
}

CalendarEvent _copyWithId(CalendarEvent e, String id) => CalendarEvent(
  id: id,
  remoteId: e.remoteId,
  calendarId: e.calendarId,
  uid: e.uid.isEmpty ? id : e.uid,
  title: e.title,
  location: e.location,
  url: e.url,
  notes: e.notes,
  startAt: e.startAt,
  endAt: e.endAt,
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

CalendarEvent _copyWithCalendar(CalendarEvent e, String calendarId) =>
    CalendarEvent(
      id: e.id,
      remoteId: e.remoteId,
      calendarId: calendarId,
      uid: e.uid,
      title: e.title,
      location: e.location,
      url: e.url,
      notes: e.notes,
      startAt: e.startAt,
      endAt: e.endAt,
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

/// Inspector 导航头（Apple 式：左关闭/删除，右保存；无 Material AppBar）。
class _InspectorHeader extends StatelessWidget {
  const _InspectorHeader({
    required this.title,
    required this.showDelete,
    required this.onDelete,
    required this.onSave,
    required this.onClose,
  });

  final String title;
  final bool showDelete;
  final VoidCallback onDelete;
  final VoidCallback onSave;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        border: Border(
          bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (showDelete)
            CupertinoButton(
              key: const Key('event_inspector_delete'),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: onDelete,
              child: const Icon(
                CupertinoIcons.delete,
                size: 22,
                color: CupertinoColors.systemRed,
              ),
            ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          CupertinoButton(
            key: const Key('event_inspector_save'),
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onSave,
            child: const Text(
              '保存',
              style: TextStyle(fontSize: 17, color: CupertinoColors.systemBlue),
            ),
          ),
          if (onClose != null)
            CupertinoButton(
              key: const Key('event_inspector_close'),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: onClose,
              child: const Icon(
                CupertinoIcons.xmark,
                size: 22,
                color: CupertinoColors.systemBlue,
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
