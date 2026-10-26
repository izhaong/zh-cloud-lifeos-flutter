import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../providers.dart';
import 'event_form_fields.dart' show EventFormFields, defaultCalendarOf;

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
    this.onClose,
  });

  final CalendarEvent initialEvent;

  /// 保存成功回调（外壳用于关闭 sheet / 清 selectedOccurrence）。
  final VoidCallback onSaved;

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
    if (!identical(oldWidget.initialEvent, widget.initialEvent)
        && oldWidget.initialEvent != widget.initialEvent) {
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
    final repo = ref.read(calendarRepositoryProvider);
    setState(() => _saving = true);
    try {
      await repo.upsertEvent(toSave);
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
          AppBar(
            title: Text(_draft.title.trim().isEmpty ? '新建日程' : _draft.title),
            actions: [
              TextButton(
                key: const Key('event_inspector_save'),
                onPressed: _save,
                child: const Text('保存'),
              ),
              if (widget.onClose != null)
                IconButton(
                  key: const Key('event_inspector_close'),
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          Expanded(
            child: EventFormFields(
              event: _draft,
              onChanged: (next) => setState(() => _draft = next),
            ),
          ),
          if (_saveAttempted && _blockedReason != null)
            Padding(
              key: const Key('event_inspector_blocked_hint'),
              padding: const EdgeInsets.all(8),
              child: Text(_blockedReason!,
                  style:
                      const TextStyle(color: Color(0xFFFF3B30), fontSize: 12)),
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
  const EventInspectorHost({super.key, required this.event, required this.onSaved});

  final CalendarEvent event;
  final VoidCallback onSaved;

  /// compact 全屏（push 新路由；route 关闭即视为取消 → onDismissed）。
  static Future<void> openFullScreen(BuildContext context, CalendarEvent event,
      VoidCallback onSaved,
      {VoidCallback? onDismissed}) {
    return Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) =>
              Scaffold(body: EventInspectorPane(initialEvent: event, onSaved: onSaved)),
        ))
        .then((_) => onDismissed?.call());
  }

  /// medium bottom sheet（sheet 关闭即视为取消 → onDismissed）。
  static Future<void> openSheet(BuildContext context, CalendarEvent event,
      VoidCallback onSaved,
      {VoidCallback? onDismissed}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: EventInspectorPane(
          initialEvent: event,
          onSaved: onSaved,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    ).then((_) => onDismissed?.call());
  }

  @override
  Widget build(BuildContext context) {
    // expanded 第三栏形态：外壳直接放进 Row 尾部。
    return EventInspectorPane(
      initialEvent: event,
      onSaved: onSaved,
      onClose: () {},
    );
  }
}


/// 新建草稿占位 id（双击/快捷创建入口统一使用；保存时换真 id）。
const String kDraftEventId = 'draft';

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
