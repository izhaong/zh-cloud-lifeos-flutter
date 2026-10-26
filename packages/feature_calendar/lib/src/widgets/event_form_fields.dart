import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../providers.dart';

/// 日程表单字段（契约 §5.4 event_form_fields.dart；F-08）。
///
/// 字段从上到下（TC-CAL-UI-132）：标题、地点、全天开关、开始、结束、时区、
/// 重复（占位，选项接 F-10）、行程时间、提醒（占位，接 F-11）、日历、
/// 显示为忙碌/空闲、私密、URL、备注。
/// 受邀者字段归 F-17（本地无邀请人搜索）。
class EventFormFields extends ConsumerStatefulWidget {
  const EventFormFields({
    super.key,
    required this.event,
    required this.onChanged,
  });

  final CalendarEvent event;

  /// 字段变更回调（父层持有草稿；保存由 Inspector 触发 upsertEvent）。
  final ValueChanged<CalendarEvent> onChanged;

  @override
  ConsumerState<EventFormFields> createState() => _EventFormFieldsState();
}

class _EventFormFieldsState extends ConsumerState<EventFormFields> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _url;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.event.title);
    _location = TextEditingController(text: widget.event.location ?? '');
    _url = TextEditingController(text: widget.event.url ?? '');
    _notes = TextEditingController(text: widget.event.notes ?? '');
  }

  @override
  void didUpdateWidget(covariant EventFormFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 新建草稿 id 恒为 kDraftEventId——按实例变化重绑（连续新建不残留旧值）
    if (!identical(oldWidget.event, widget.event)
        && oldWidget.event != widget.event) {
      _title.text = widget.event.title;
      _location.text = widget.event.location ?? '';
      _url.text = widget.event.url ?? '';
      _notes.text = widget.event.notes ?? '';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  CalendarEvent get _e => widget.event;

  void _emit(CalendarEvent next) => widget.onChanged(next);

  @override
  Widget build(BuildContext context) {
    final calendars = ref.watch(calendarsProvider).value ?? const <Calendar>[];
    final titleEmpty = _title.text.trim().isEmpty;

    return ListView(
      key: const Key('event_form_fields'),
      children: [
        // 1. 标题
        TextField(
          key: const Key('event_field_title'),
          controller: _title,
          decoration: const InputDecoration(labelText: '标题'),
          onChanged: (_) => _emit(_copyWith(_e, title: _title.text)),
        ),
        // 2. 地点
        TextField(
          key: const Key('event_field_location'),
          controller: _location,
          decoration: const InputDecoration(labelText: '地点'),
          onChanged: (_) => _emit(_copyWith(_e, location: _location.text)),
        ),
        // 3. 全天开关
        SwitchListTile(
          key: const Key('event_field_all_day'),
          title: const Text('全天'),
          value: _e.allDay,
          onChanged: (v) => _emit(_copyWith(_e, allDay: v)),
        ),
        // 4/5. 开始 / 结束
        ListTile(
          key: const Key('event_field_start'),
          title: const Text('开始'),
          trailing: Text(_e.allDay
              ? '${_e.startAt.year}-${_e.startAt.month}-${_e.startAt.day}'
              : _e.startAt.toIso8601String()),
        ),
        ListTile(
          key: const Key('event_field_end'),
          title: const Text('结束'),
          trailing: Text(_e.allDay
              ? '${_e.endAt.year}-${_e.endAt.month}-${_e.endAt.day}'
              : _e.endAt.toIso8601String()),
        ),
        // 6. 时区
        ListTile(
          key: const Key('event_field_timezone'),
          title: const Text('时区'),
          trailing: Text(_e.timeZone),
        ),
        // 7. 重复（占位下拉；选项接 F-10）
        ListTile(
          key: const Key('event_field_repeat'),
          title: const Text('重复'),
          trailing: const Text('不重复'),
          onTap: () {/* F-10 重复 UI */},
        ),
        // 8. 行程时间
        ListTile(
          key: const Key('event_field_travel'),
          title: const Text('行程时间'),
          trailing: Text(_e.travelMinutes == null ? '无' : '${_e.travelMinutes} 分钟'),
        ),
        // 9. 提醒（占位下拉；接 F-11）
        ListTile(
          key: const Key('event_field_alerts'),
          title: const Text('提醒'),
          trailing: Text(_e.alerts.isEmpty ? '无' : '${_e.alerts.length} 个'),
          onTap: () {/* F-11 提醒 UI */},
        ),
        // 10. 日历
        ListTile(
          key: const Key('event_field_calendar'),
          title: const Text('日历'),
          trailing: DropdownButton<String>(
            key: const Key('event_field_calendar_dropdown'),
            value: calendars.any((c) => c.id == _e.calendarId)
                ? _e.calendarId
                : (calendars.isEmpty ? null : calendars.first.id),
            items: [
              for (final c in calendars)
                DropdownMenuItem(value: c.id, child: Text(c.title)),
            ],
            onChanged: (id) {
              if (id != null) {
                _emit(_copyWith(_e, calendarId: id));
              }
            },
          ),
        ),
        // 11. 显示为（忙碌/空闲）——窄屏 trailing 放不下 SegmentedButton：
        // 用单行下拉（视觉同 Apple「显示为」），宽屏亦不溢出。
        ListTile(
          key: const Key('event_field_availability'),
          title: const Text('显示为'),
          trailing: DropdownButton<EventAvailability>(
            value: _e.availability,
            items: const [
              DropdownMenuItem(
                  value: EventAvailability.busy, child: Text('忙碌')),
              DropdownMenuItem(
                  value: EventAvailability.free, child: Text('空闲')),
            ],
            onChanged: (v) {
              if (v != null) {
                _emit(_copyWith(_e, availability: v));
              }
            },
          ),
        ),
        // 12. 私密
        SwitchListTile(
          key: const Key('event_field_private'),
          title: const Text('私密'),
          value: _e.isPrivate,
          onChanged: (v) => _emit(_copyWith(_e, isPrivate: v)),
        ),
        // 13. URL
        TextField(
          key: const Key('event_field_url'),
          controller: _url,
          decoration: const InputDecoration(labelText: 'URL'),
          onChanged: (_) => _emit(_copyWith(_e, url: _url.text)),
        ),
        // 14. 备注
        TextField(
          key: const Key('event_field_notes'),
          controller: _notes,
          decoration: const InputDecoration(labelText: '备注'),
          maxLines: 3,
          onChanged: (_) => _emit(_copyWith(_e, notes: _notes.text)),
        ),
        if (titleEmpty)
          const Padding(
            key: Key('event_field_title_required_hint'),
            padding: EdgeInsets.all(8),
            child: Text('标题不能为空',
                style: TextStyle(color: Color(0xFFFF3B30), fontSize: 12)),
          ),
      ],
    );
  }
}

/// 全字段拷贝（kernel 模型无 copyWith；照 withTimes 风格在表单层实现）。
CalendarEvent _copyWith(
  CalendarEvent e, {
  String? title,
  String? location,
  bool? allDay,
  String? calendarId,
  EventAvailability? availability,
  bool? isPrivate,
  String? url,
  String? notes,
}) {
  return CalendarEvent(
    id: e.id,
    remoteId: e.remoteId,
    calendarId: calendarId ?? e.calendarId,
    uid: e.uid,
    title: title ?? e.title,
    location: location ?? e.location,
    url: url ?? e.url,
    notes: notes ?? e.notes,
    startAt: e.startAt,
    endAt: e.endAt,
    allDay: allDay ?? e.allDay,
    timeZone: e.timeZone,
    isFloating: e.isFloating,
    rrule: e.rrule,
    exdates: e.exdates,
    parentEventId: e.parentEventId,
    originalStartAt: e.originalStartAt,
    status: e.status,
    availability: availability ?? e.availability,
    travelMinutes: e.travelMinutes,
    isPrivate: isPrivate ?? e.isPrivate,
    alerts: e.alerts,
    invitees: e.invitees,
    sequence: e.sequence,
    revision: e.revision,
    deletedAt: e.deletedAt,
    updatedAt: e.updatedAt,
  );
}
