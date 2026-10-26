import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cupertino_calendar_picker/cupertino_calendar_picker.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../logic/event_time.dart';
import '../logic/calendar_ids.dart';
import '../logic/recurrence_ui.dart';
import '../logic/alert_triggers.dart';
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
    _applyDeviceZoneToNewDraft();
  }

  /// 新建草稿默认使用设备本地时区（F-09；创建入口给的是 UTC 占位）。
  Future<void> _applyDeviceZoneToNewDraft() async {
    if (widget.event.id != kDraftEventId) {
      return;
    }
    final zone = await ref.read(deviceTimeZoneProvider.future);
    if (!mounted || zone == 'UTC') {
      return;
    }
    if (widget.event.timeZone == 'UTC') {
      _emit(copyEventWithTimes(widget.event, timeZone: zone));
    }
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

  // F-09：日期/时间选择（cupertino_calendar_picker 2.2.6，契约 §8.3）
  Future<void> _pickStart(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final zone = _e.timeZone;
    final wall = wallTimeOf(_e.startAt, zone);
    final picked = await showCupertinoCalendarPicker(
      context,
      widgetRenderBox: box,
      minimumDateTime: DateTime(2000),
      maximumDateTime: DateTime(2100, 12, 31),
      initialDateTime:
          DateTime(wall.year, wall.month, wall.day, wall.hour, wall.minute),
      mode: _e.allDay
          ? CupertinoCalendarMode.date
          : CupertinoCalendarMode.dateTime,
    );
    if (picked == null || !mounted) {
      return;
    }
    final wallTime = _e.allDay
        ? DateTime(picked.year, picked.month, picked.day)
        : DateTime(picked.year, picked.month, picked.day, picked.hour,
            picked.minute);
    _emit(setStart(_e, utcFromWall(wallTime, zone)));
  }

  Future<void> _pickEnd(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final zone = _e.timeZone;
    final wall = wallTimeOf(_e.endAt, zone);
    final picked = await showCupertinoCalendarPicker(
      context,
      widgetRenderBox: box,
      minimumDateTime: DateTime(2000),
      maximumDateTime: DateTime(2100, 12, 31),
      initialDateTime:
          DateTime(wall.year, wall.month, wall.day, wall.hour, wall.minute),
      mode: _e.allDay
          ? CupertinoCalendarMode.date
          : CupertinoCalendarMode.dateTime,
    );
    if (picked == null || !mounted) {
      return;
    }
    if (_e.allDay) {
      // 全天结束排他：所选日期次日当地 00:00（按日历日 +1，不受 DST 影响）
      final endLocal =
          DateTime(picked.year, picked.month, picked.day + 1);
      final end = utcFromWall(endLocal, zone);
      if (end.isAfter(_e.startAt)) {
        _emit(copyEventWithTimes(_e, endAt: end));
      }
      return;
    }
    final end = utcFromWall(
        DateTime(picked.year, picked.month, picked.day, picked.hour,
            picked.minute),
        zone);
    if (end.isAfter(_e.startAt)) {
      _emit(setEnd(_e, end));
    }
  }

  Future<void> _pickTimeZone() async {
    final zone = await showDialog<String>(
      context: context,
      builder: (_) => _TimeZoneDialog(selected: _e.timeZone),
    );
    if (zone != null && mounted && zone != _e.timeZone) {
      _emit(setTimeZone(_e, zone));
    }
  }

  /// 自定义重复：编辑器返回配置 → 生成 RRULE（F-10）。
  Future<void> _editRecurrence() async {
    final config = await showDialog<RecurrenceConfig>(
      context: context,
      builder: (_) => _RecurrenceEditorDialog(
        initial: parseRRule(_e.rrule, _e.startAt),
        startAt: _e.startAt,
      ),
    );
    if (config != null && mounted) {
      _emit(_copyWithRrule(_e, buildRRule(config, _e.startAt)));
    }
  }

  /// 多选提醒（F-11；全天用「天 + 时刻」，定时用偏移分钟）。
  Future<void> _pickAlerts(CalendarPreference pref) async {
    final result = await showDialog<List<EventAlert>>(
      context: context,
      builder: (_) => _AlertsDialog(
        allDay: _e.allDay,
        initial: _e.alerts,
        allDayTime: pref.defaultAlertAllDayTime,
      ),
    );
    if (result != null && mounted) {
      _emit(_copyWithAlerts(_e, result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendars = ref.watch(calendarsProvider).value ?? const <Calendar>[];
    final pref =
        ref.watch(preferenceProvider).value ?? const CalendarPreference();
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
        // 3. 全天开关（切换即按契约 §2.2 归一，TC-CAL-UI-140）
        SwitchListTile(
          key: const Key('event_field_all_day'),
          title: const Text('全天'),
          value: _e.allDay,
          onChanged: (v) => _emit(setAllDay(_e, v)),
        ),
        // 4/5. 开始 / 结束（全天隐藏时刻；点击走 Cupertino picker）
        Builder(
          builder: (ctx) => ListTile(
            key: const Key('event_field_start'),
            title: const Text('开始'),
            trailing: Text(
              formatEventWall(_e.startAt, _e.timeZone, allDay: _e.allDay),
            ),
            onTap: () => _pickStart(ctx),
          ),
        ),
        Builder(
          builder: (ctx) => ListTile(
            key: const Key('event_field_end'),
            title: const Text('结束'),
            trailing: Text(
              formatEventWall(_e.endAt, _e.timeZone, allDay: _e.allDay),
            ),
            onTap: () => _pickEnd(ctx),
          ),
        ),
        // 6. 时区（timezone 包全量列表；默认设备本地时区）
        ListTile(
          key: const Key('event_field_timezone'),
          title: const Text('时区'),
          trailing: Text(_e.timeZone),
          onTap: _pickTimeZone,
        ),
        // 6.1 浮动时间（仅偏好 timeZoneSupport=true 时显示，TC-CAL-UI-140）
        if (pref.timeZoneSupport)
          SwitchListTile(
            key: const Key('event_field_floating'),
            title: const Text('浮动时间'),
            subtitle: const Text('不随时区换算'),
            value: _e.isFloating,
            onChanged: (v) =>
                _emit(copyEventWithTimes(_e, isFloating: v)),
          ),
        // 7. 重复（预设下拉 + 自定义编辑器；F-10）
        ListTile(
          key: const Key('event_field_repeat'),
          title: const Text('重复'),
          trailing: DropdownButton<RecurrencePreset>(
            key: const Key('event_field_repeat_dropdown'),
            value: presetOf(_e.rrule),
            items: [
              for (final p in RecurrencePreset.values)
                DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: (p) {
              if (p == null) {
                return;
              }
              if (p == RecurrencePreset.custom) {
                _editRecurrence();
              } else {
                _emit(_copyWithRrule(_e, rruleForPreset(p, _e.startAt)));
              }
            },
          ),
        ),
        // 8. 行程时间
        ListTile(
          key: const Key('event_field_travel'),
          title: const Text('行程时间'),
          trailing: Text(_e.travelMinutes == null ? '无' : '${_e.travelMinutes} 分钟'),
        ),
        // 9. 提醒（多选；F-11）
        ListTile(
          key: const Key('event_field_alerts'),
          title: const Text('提醒'),
          trailing: Text(
              _e.alerts.isEmpty ? '无' : '${_e.alerts.length} 个'),
          onTap: () => _pickAlerts(pref),
        ),
        // 10. 日历
        ListTile(
          key: const Key('event_field_calendar'),
          title: const Text('日历'),
          trailing: DropdownButton<String>(
            key: const Key('event_field_calendar_dropdown'),
            value: calendars.any((c) => c.id == _e.calendarId)
                ? _e.calendarId
                : defaultCalendarOf(calendars)?.id,
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
    allDay: e.allDay,
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


/// 草稿空日历的落点：优先默认**可写**日历，否则首个可写日历
/// （订阅/节假日/VIEW 共享不可落库；与 Inspector 保存口径一致）。
Calendar? defaultCalendarOf(List<Calendar> calendars) {
  final writable = calendars
      .where((c) => c.kind == CalendarKind.local ||
          (c.kind == CalendarKind.shared &&
              c.permission != CalendarPermission.view))
      .toList();
  if (writable.isEmpty) {
    return null;
  }
  return writable.any((c) => c.isDefault)
      ? writable.firstWhere((c) => c.isDefault)
      : writable.first;
}

/// 时区选择对话框（timezone 包全量；搜索过滤；F-09 TC-CAL-UI-140）。
class _TimeZoneDialog extends StatefulWidget {
  const _TimeZoneDialog({required this.selected});

  final String selected;

  @override
  State<_TimeZoneDialog> createState() => _TimeZoneDialogState();
}

class _TimeZoneDialogState extends State<_TimeZoneDialog> {
  late final List<String> _all = allTimeZoneNames();
  late String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = _all
        .where((z) => z.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return AlertDialog(
      key: const Key('event_timezone_dialog'),
      title: const Text('时区'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const Key('event_timezone_search'),
              decoration: const InputDecoration(hintText: '搜索时区'),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                key: const Key('event_timezone_list'),
                itemCount: matches.length,
                itemBuilder: (_, i) {
                  final name = matches[i];
                  return ListTile(
                    key: Key('event_timezone_option_$name'),
                    title: Text(name),
                    trailing: name == widget.selected
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(context).pop(name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('event_timezone_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

/// 重复规则全量拷贝（kernel 无 copyWith）。
CalendarEvent _copyWithRrule(CalendarEvent e, String? rrule) => CalendarEvent(
      id: e.id,
      remoteId: e.remoteId,
      calendarId: e.calendarId,
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
      rrule: rrule,
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

/// 自定义重复编辑器（契约 §3.2.1 频率/间隔/周几/第 N 个周 X/结束；F-10）。
class _RecurrenceEditorDialog extends StatefulWidget {
  const _RecurrenceEditorDialog({required this.initial, required this.startAt});

  final RecurrenceConfig initial;
  final DateTime startAt;

  @override
  State<_RecurrenceEditorDialog> createState() =>
      _RecurrenceEditorDialogState();
}

class _RecurrenceEditorDialogState extends State<_RecurrenceEditorDialog> {
  late final RecurrenceConfig _c = widget.initial;
  late final TextEditingController _interval =
      TextEditingController(text: '${widget.initial.interval}');
  late final TextEditingController _count = TextEditingController(
      text: widget.initial.count == null ? '' : '${widget.initial.count}');

  @override
  void dispose() {
    _interval.dispose();
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('recurrence_editor'),
      title: const Text('自定义重复'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('recurrence_freq'),
                initialValue: _c.freq,
                decoration: const InputDecoration(labelText: '频率'),
                items: const [
                  DropdownMenuItem(value: kFreqDaily, child: Text('每天')),
                  DropdownMenuItem(value: kFreqWeekly, child: Text('每周')),
                  DropdownMenuItem(value: kFreqMonthly, child: Text('每月')),
                  DropdownMenuItem(value: kFreqYearly, child: Text('每年')),
                ],
                onChanged: (v) => setState(() => _c.freq = v ?? _c.freq),
              ),
              TextField(
                key: const Key('recurrence_interval'),
                controller: _interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '间隔'),
                onChanged: (v) => _c.interval = int.tryParse(v) ?? 1,
              ),
              if (_c.freq == kFreqWeekly)
                Wrap(
                  key: const Key('recurrence_weekdays'),
                  spacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        key: Key('recurrence_weekday_$d'),
                        label: Text(kWeekdayCodes[d - 1]),
                        selected: _c.weekdays.contains(d),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _c.weekdays.add(d);
                          } else {
                            _c.weekdays.remove(d);
                          }
                        }),
                      ),
                  ],
                ),
              if (_c.freq == kFreqMonthly)
                SwitchListTile(
                  key: const Key('recurrence_monthly_same_day'),
                  title: const Text('每月同日'),
                  value: _c.monthlyByDayOfMonth,
                  onChanged: (v) =>
                      setState(() => _c.monthlyByDayOfMonth = v),
                ),
              if (_c.freq == kFreqMonthly && !_c.monthlyByDayOfMonth)
                Row(
                  children: [
                    DropdownButton<int>(
                      key: const Key('recurrence_ordinal'),
                      value: _c.ordinal,
                      items: [
                        for (final o in kOrdinalChoices)
                          DropdownMenuItem(
                            value: o,
                            child: Text(o == -1 ? '最后' : '第 $o'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _c.ordinal = v ?? 1),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      key: const Key('recurrence_ordinal_weekday'),
                      value: _c.ordinalWeekday,
                      items: [
                        for (var d = 1; d <= 7; d++)
                          DropdownMenuItem(
                            value: d,
                            child: Text(kWeekdayCodes[d - 1]),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _c.ordinalWeekday = v ?? 1),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('recurrence_end'),
                initialValue: _c.count != null
                    ? 'count'
                    : (_c.until != null ? 'until' : 'never'),
                decoration: const InputDecoration(labelText: '结束'),
                items: const [
                  DropdownMenuItem(value: 'never', child: Text('永不')),
                  DropdownMenuItem(value: 'until', child: Text('日期')),
                  DropdownMenuItem(value: 'count', child: Text('次数')),
                ],
                onChanged: (v) => setState(() {
                  _c.count = v == 'count' ? (_c.count ?? 10) : null;
                  _c.until = v == 'until'
                      ? (_c.until ??
                          widget.startAt.toUtc().add(const Duration(days: 30)))
                      : null;
                }),
              ),
              if (_c.count != null)
                TextField(
                  key: const Key('recurrence_count'),
                  controller: _count,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '次数'),
                  onChanged: (v) => _c.count = int.tryParse(v),
                ),
              if (_c.until != null)
                ListTile(
                  key: const Key('recurrence_until'),
                  title: const Text('结束日期'),
                  trailing: Text(
                      '${_c.until!.year}-${_c.until!.month}-${_c.until!.day}'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _c.until!,
                      firstDate: widget.startAt,
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _c.until = picked);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('recurrence_editor_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('recurrence_editor_save'),
          onPressed: () => Navigator.of(context).pop(_c),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

/// 提醒全量拷贝（kernel 无 copyWith）。
CalendarEvent _copyWithAlerts(CalendarEvent e, List<EventAlert> alerts) =>
    CalendarEvent(
      id: e.id,
      remoteId: e.remoteId,
      calendarId: e.calendarId,
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
      alerts: alerts,
      invitees: e.invitees,
      sequence: e.sequence,
      revision: e.revision,
      deletedAt: e.deletedAt,
      updatedAt: e.updatedAt,
    );

/// 多选提醒对话框（契约 §2.3 预设；F-11）。
class _AlertsDialog extends StatefulWidget {
  const _AlertsDialog({
    required this.allDay,
    required this.initial,
    required this.allDayTime,
  });

  final bool allDay;
  final List<EventAlert> initial;
  final String allDayTime;

  @override
  State<_AlertsDialog> createState() => _AlertsDialogState();
}

class _AlertsDialogState extends State<_AlertsDialog> {
  late final Set<int> _timed = {
    for (final a in widget.initial)
      if (a.offsetMinutes != null) a.offsetMinutes!,
  };
  late final Set<int> _days = {
    for (final a in widget.initial)
      if (a.allDayOffsetDays != null) a.allDayOffsetDays!,
  };
  late final String _time = widget.initial
          .firstWhere((a) => a.allDayTime != null,
              orElse: () => EventAlert(allDayTime: widget.allDayTime))
          .allDayTime ??
      widget.allDayTime;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('alerts_dialog'),
      title: const Text('提醒'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: widget.allDay ? _buildAllDay() : _buildTimed(),
      ),
      actions: [
        TextButton(
          key: const Key('alerts_dialog_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('alerts_dialog_save'),
          onPressed: () => Navigator.of(context).pop(_buildResult()),
          child: const Text('完成'),
        ),
      ],
    );
  }

  Widget _buildTimed() {
    return ListView(
      children: [
        for (final offset in kTimedAlertOffsets)
          CheckboxListTile(
            key: Key('alert_timed_$offset'),
            title: Text(timedAlertLabel(offset)),
            value: _timed.contains(offset),
            onChanged: (on) => setState(() {
              if (on == true) {
                _timed.add(offset);
              } else {
                _timed.remove(offset);
              }
            }),
          ),
      ],
    );
  }

  Widget _buildAllDay() {
    return ListView(
      children: [
        for (final days in kAllDayAlertDays)
          CheckboxListTile(
            key: Key('alert_allday_$days'),
            title: Text(allDayAlertLabel(days, _time)),
            value: _days.contains(days),
            onChanged: (on) => setState(() {
              if (on == true) {
                _days.add(days);
              } else {
                _days.remove(days);
              }
            }),
          ),
      ],
    );
  }

  List<EventAlert> _buildResult() {
    if (widget.allDay) {
      return [
        for (final days in kAllDayAlertDays)
          if (_days.contains(days))
            EventAlert(allDayOffsetDays: days, allDayTime: _time),
      ];
    }
    return [
      for (final offset in kTimedAlertOffsets)
        if (_timed.contains(offset)) EventAlert(offsetMinutes: offset),
    ];
  }
}
