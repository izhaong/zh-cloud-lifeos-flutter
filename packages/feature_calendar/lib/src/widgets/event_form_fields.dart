import 'package:cupertino_calendar_picker/cupertino_calendar_picker.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../logic/event_time.dart';
import '../logic/calendar_ids.dart';
import '../logic/recurrence_ui.dart';
import '../logic/alert_triggers.dart';
import '../providers.dart';

/// 日程表单字段（契约 §5.4 event_form_fields.dart；F-08）。
///
/// 字段从上到下（TC-CAL-UI-132）：标题、地点、全天开关、开始、结束、时区、
/// 重复（预设 + 自定义接 F-10）、行程时间、提醒（F-11）、日历、
/// 显示为忙碌/空闲、私密、URL、备注。Cupertino 化（#130）：
/// 文本框 CupertinoTextField、开关 CupertinoSwitch、下拉改 ActionSheet。
/// 受邀者字段归 F-17（本地无邀请人搜索）。
class EventFormFields extends ConsumerStatefulWidget {
  const EventFormFields({
    super.key,
    required this.event,
    required this.onChanged,
    this.showTitleRequired = false,
  });

  final CalendarEvent event;

  /// 字段变更回调（父层持有草稿；保存由 Inspector 触发 upsertEvent）。
  final ValueChanged<CalendarEvent> onChanged;

  /// 是否展示「标题不能为空」提示（#177：仅在保存尝试后由 Inspector 置真）。
  final bool showTitleRequired;

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
    if (!identical(oldWidget.event, widget.event) &&
        oldWidget.event != widget.event) {
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
      initialDateTime: DateTime(
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
      ),
      mode: _e.allDay
          ? CupertinoCalendarMode.date
          : CupertinoCalendarMode.dateTime,
    );
    if (picked == null || !mounted) {
      return;
    }
    final wallTime = _e.allDay
        ? DateTime(picked.year, picked.month, picked.day)
        : DateTime(
            picked.year,
            picked.month,
            picked.day,
            picked.hour,
            picked.minute,
          );
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
      initialDateTime: DateTime(
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
      ),
      mode: _e.allDay
          ? CupertinoCalendarMode.date
          : CupertinoCalendarMode.dateTime,
    );
    if (picked == null || !mounted) {
      return;
    }
    if (_e.allDay) {
      // 全天结束排他：所选日期次日当地 00:00（按日历日 +1，不受 DST 影响）
      final endLocal = DateTime(picked.year, picked.month, picked.day + 1);
      final end = utcFromWall(endLocal, zone);
      if (end.isAfter(_e.startAt)) {
        _emit(copyEventWithTimes(_e, endAt: end));
      }
      return;
    }
    final end = utcFromWall(
      DateTime(
        picked.year,
        picked.month,
        picked.day,
        picked.hour,
        picked.minute,
      ),
      zone,
    );
    if (end.isAfter(_e.startAt)) {
      _emit(setEnd(_e, end));
    }
  }

  Future<void> _pickTimeZone() async {
    final zone = await showCupertinoDialog<String>(
      context: context,
      builder: (_) => _TimeZoneDialog(selected: _e.timeZone),
    );
    if (zone != null && mounted && zone != _e.timeZone) {
      _emit(setTimeZone(_e, zone));
    }
  }

  /// 自定义重复：编辑器返回配置 → 生成 RRULE（F-10）。
  Future<void> _editRecurrence() async {
    final config = await showCupertinoDialog<RecurrenceConfig>(
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
    final result = await showCupertinoDialog<List<EventAlert>>(
      context: context,
      builder: (_) => _AlertsDialog(
        allDay: _e.allDay,
        initial: _e.alerts,
        allDayTime: pref.defaultAlertAllDayTime,
      ),
    );
    if (result != null && mounted) {
      _emit(copyEventWithAlerts(_e, result));
    }
  }

  /// 通用选项弹层（iOS ActionSheet；测试契约：tap 触发钮 → tap 选项文案）。
  Future<T?> _showOptionSheet<T>(
    List<({T value, String label})> options, {
    required bool Function(T) isSelected,
  }) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          for (final o in options)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(o.value),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected(o.value)) ...[
                    const Icon(CupertinoIcons.checkmark, size: 16),
                    const SizedBox(width: 4),
                  ],
                  Text(o.label),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendars = ref.watch(calendarsProvider).value ?? const <Calendar>[];
    final pref =
        ref.watch(preferenceProvider).value ?? const CalendarPreference();
    final titleEmpty = _title.text.trim().isEmpty;
    final currentPreset = presetOf(_e.rrule);
    final currentCalendarId = calendars.any((c) => c.id == _e.calendarId)
        ? _e.calendarId
        : defaultCalendarOf(calendars)?.id;

    return ListView(
      key: const Key('event_form_fields'),
      children: [
        // 1. 标题
        _TextFieldRow(
          fieldKey: const Key('event_field_title'),
          controller: _title,
          placeholder: '标题',
          onChanged: (v) => _emit(_copyWith(_e, title: v)),
        ),
        // 2. 地点
        _TextFieldRow(
          fieldKey: const Key('event_field_location'),
          controller: _location,
          placeholder: '地点',
          onChanged: (v) => _emit(_copyWith(_e, location: v)),
        ),
        // 3. 全天开关（切换即按契约 §2.2 归一，TC-CAL-UI-140）
        _SwitchRow(
          rowKey: const Key('event_field_all_day'),
          title: '全天',
          value: _e.allDay,
          onChanged: (v) => _emit(setAllDay(_e, v)),
        ),
        // 4/5. 开始 / 结束（全天隐藏时刻；点击走 Cupertino picker）
        Builder(
          builder: (ctx) => _FieldRow(
            rowKey: const Key('event_field_start'),
            title: '开始',
            trailing: Text(
              formatEventWall(_e.startAt, _e.timeZone, allDay: _e.allDay),
            ),
            onTap: () => _pickStart(ctx),
          ),
        ),
        Builder(
          builder: (ctx) => _FieldRow(
            rowKey: const Key('event_field_end'),
            title: '结束',
            trailing: Text(
              formatEventWall(_e.endAt, _e.timeZone, allDay: _e.allDay),
            ),
            onTap: () => _pickEnd(ctx),
          ),
        ),
        // 6. 时区（timezone 包全量列表；默认设备本地时区）
        _FieldRow(
          rowKey: const Key('event_field_timezone'),
          title: '时区',
          trailing: Text(_e.timeZone),
          onTap: _pickTimeZone,
        ),
        // 6.1 浮动时间（仅偏好 timeZoneSupport=true 时显示，TC-CAL-UI-140）
        if (pref.timeZoneSupport)
          _SwitchRow(
            rowKey: const Key('event_field_floating'),
            title: '浮动时间',
            subtitle: '不随时区换算',
            value: _e.isFloating,
            onChanged: (v) => _emit(copyEventWithTimes(_e, isFloating: v)),
          ),
        // 7. 重复（预设 ActionSheet + 自定义编辑器；F-10）
        _FieldRow(
          rowKey: const Key('event_field_repeat'),
          title: '重复',
          trailing: CupertinoButton(
            key: const Key('event_field_repeat_dropdown'),
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            onPressed: () async {
              final p = await _showOptionSheet<RecurrencePreset>([
                for (final preset in RecurrencePreset.values)
                  (value: preset, label: preset.label),
              ], isSelected: (v) => v == currentPreset);
              if (p == null || !mounted) {
                return;
              }
              if (p == RecurrencePreset.custom) {
                _editRecurrence();
              } else {
                _emit(_copyWithRrule(_e, rruleForPreset(p, _e.startAt)));
              }
            },
            child: Text(
              currentPreset.label,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
        // 8. 行程时间（#188：Apple 预设 无/5/15/30/60/90/120）
        _FieldRow(
          rowKey: const Key('event_field_travel'),
          title: '行程时间',
          trailing: CupertinoButton(
            key: const Key('event_field_travel_dropdown'),
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            onPressed: () async {
              final minutes = await _showOptionSheet<int>([
                (value: 0, label: '无'),
                for (final m in const [5, 15, 30, 60, 90, 120])
                  (value: m, label: '$m 分钟'),
              ], isSelected: (v) {
                if (v == 0) {
                  return _e.travelMinutes == null;
                }
                return v == _e.travelMinutes;
              });
              if (minutes == null || !mounted) {
                return;
              }
              _emit(
                minutes == 0
                    ? _copyWith(_e, clearTravel: true)
                    : _copyWith(_e, travelMinutes: minutes),
              );
            },
            child: Text(
              _e.travelMinutes == null ? '无' : '${_e.travelMinutes} 分钟',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
        // 9. 提醒（多选；F-11）
        _FieldRow(
          rowKey: const Key('event_field_alerts'),
          title: '提醒',
          trailing: Text(_e.alerts.isEmpty ? '无' : '${_e.alerts.length} 个'),
          onTap: () => _pickAlerts(pref),
        ),
        // 10. 日历
        _FieldRow(
          rowKey: const Key('event_field_calendar'),
          title: '日历',
          trailing: CupertinoButton(
            key: const Key('event_field_calendar_dropdown'),
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            onPressed: () async {
              final id = await _showOptionSheet<String>([
                for (final c in calendars) (value: c.id, label: c.title),
              ], isSelected: (v) => v == currentCalendarId);
              if (id != null && mounted) {
                _emit(_copyWith(_e, calendarId: id));
              }
            },
            child: Text(
              calendars
                      .where((c) => c.id == currentCalendarId)
                      .firstOrNull
                      ?.title ??
                  '无',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
        // 11. 显示为（忙碌/空闲）——iOS「显示为」ActionSheet，宽屏亦不溢出。
        _FieldRow(
          rowKey: const Key('event_field_availability'),
          title: '显示为',
          trailing: CupertinoButton(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            onPressed: () async {
              final v = await _showOptionSheet<EventAvailability>(const [
                (value: EventAvailability.busy, label: '忙碌'),
                (value: EventAvailability.free, label: '空闲'),
              ], isSelected: (v) => v == _e.availability);
              if (v != null && mounted) {
                _emit(_copyWith(_e, availability: v));
              }
            },
            child: Text(
              _e.availability == EventAvailability.busy ? '忙碌' : '空闲',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
        // 12. 私密
        _SwitchRow(
          rowKey: const Key('event_field_private'),
          title: '私密',
          value: _e.isPrivate,
          onChanged: (v) => _emit(_copyWith(_e, isPrivate: v)),
        ),
        // 13. URL
        _TextFieldRow(
          fieldKey: const Key('event_field_url'),
          controller: _url,
          placeholder: 'URL',
          onChanged: (v) => _emit(_copyWith(_e, url: v)),
        ),
        // 14. 备注
        _TextFieldRow(
          fieldKey: const Key('event_field_notes'),
          controller: _notes,
          placeholder: '备注',
          maxLines: 3,
          onChanged: (v) => _emit(_copyWith(_e, notes: v)),
        ),
        if (titleEmpty && widget.showTitleRequired)
          const Padding(
            key: Key('event_field_title_required_hint'),
            padding: EdgeInsets.all(8),
            child: Text(
              '标题不能为空',
              style: TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// 表单行：标题 + 可收缩 trailing（Ahem 字体下固定宽文本会溢出）+ 底部细线。
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.rowKey,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final Key rowKey;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: rowKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(width: 0.5, color: CupertinoColors.separator),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: trailing!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 带副标题的开关行（整行 key 供测试 tap；开关自身也可点）。
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.rowKey,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final Key rowKey;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: rowKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(width: 0.5, color: CupertinoColors.separator),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CupertinoSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// 文本字段行（key 落在 CupertinoTextField 上供 enterText）。
class _TextFieldRow extends StatelessWidget {
  const _TextFieldRow({
    required this.fieldKey,
    required this.controller,
    required this.placeholder,
    required this.onChanged,
    this.maxLines = 1,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(width: 0.5, color: CupertinoColors.separator),
        ),
      ),
      child: CupertinoTextField(
        key: fieldKey,
        controller: controller,
        placeholder: placeholder,
        maxLines: maxLines,
        minLines: 1,
        decoration: const BoxDecoration(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        onChanged: onChanged,
      ),
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
  int? travelMinutes,
  bool clearTravel = false,
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
    travelMinutes: clearTravel ? null : (travelMinutes ?? e.travelMinutes),
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
      .where(
        (c) =>
            c.kind == CalendarKind.local ||
            (c.kind == CalendarKind.shared &&
                c.permission != CalendarPermission.view),
      )
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
    return CupertinoAlertDialog(
      key: const Key('event_timezone_dialog'),
      title: const Text('时区'),
      content: SizedBox(
        height: 420,
        width: double.maxFinite,
        child: Column(
          children: [
            CupertinoTextField(
              key: const Key('event_timezone_search'),
              placeholder: '搜索时区',
              decoration: BoxDecoration(
                color: const Color(0xFFE9E9EB),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                key: const Key('event_timezone_list'),
                itemCount: matches.length,
                itemBuilder: (_, i) {
                  final name = matches[i];
                  return GestureDetector(
                    key: Key('event_timezone_option_$name'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 0.5,
                            color: CupertinoColors.separator,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          if (name == widget.selected)
                            const Icon(
                              CupertinoIcons.checkmark,
                              size: 16,
                              color: CupertinoColors.systemBlue,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
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
/// Cupertino 化：频率/结束用滑动分段，周几用自绘 chip，日期走 CupertinoDatePicker。
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
  late final TextEditingController _interval = TextEditingController(
    text: '${widget.initial.interval}',
  );
  late final TextEditingController _count = TextEditingController(
    text: widget.initial.count == null ? '' : '${widget.initial.count}',
  );

  @override
  void dispose() {
    _interval.dispose();
    _count.dispose();
    super.dispose();
  }

  String get _endMode =>
      _c.count != null ? 'count' : (_c.until != null ? 'until' : 'never');

  Future<void> _pickUntil() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 64),
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('完成'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _c.until!,
                  minimumDate: widget.startAt,
                  maximumDate: DateTime(2100),
                  onDateTimeChanged: (v) => setState(() => _c.until = v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickOrdinal() async {
    final o = await showCupertinoModalPopup<int>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          for (final choice in kOrdinalChoices)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(choice),
              child: Text(choice == -1 ? '最后' : '第 $choice'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (o != null) {
      setState(() => _c.ordinal = o);
    }
  }

  Future<void> _pickOrdinalWeekday() async {
    final d = await showCupertinoModalPopup<int>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          for (var day = 1; day <= 7; day++)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(day),
              child: Text(kWeekdayCodes[day - 1]),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (d != null) {
      setState(() => _c.ordinalWeekday = d);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      key: const Key('recurrence_editor'),
      title: const Text('自定义重复'),
      content: SizedBox(
        height: 440,
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _EditorLabel('频率'),
              CupertinoSlidingSegmentedControl<String>(
                key: const Key('recurrence_freq'),
                groupValue: _c.freq,
                children: const {
                  kFreqDaily: Text('每天'),
                  kFreqWeekly: Text('每周'),
                  kFreqMonthly: Text('每月'),
                  kFreqYearly: Text('每年'),
                },
                onValueChanged: (v) => setState(() => _c.freq = v ?? _c.freq),
              ),
              const _EditorLabel('间隔'),
              CupertinoTextField(
                key: const Key('recurrence_interval'),
                controller: _interval,
                keyboardType: TextInputType.number,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E9EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                onChanged: (v) => _c.interval = int.tryParse(v) ?? 1,
              ),
              if (_c.freq == kFreqWeekly) ...[
                const _EditorLabel('周几'),
                Wrap(
                  key: const Key('recurrence_weekdays'),
                  spacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      GestureDetector(
                        key: Key('recurrence_weekday_$d'),
                        onTap: () => setState(() {
                          if (_c.weekdays.contains(d)) {
                            _c.weekdays.remove(d);
                          } else {
                            _c.weekdays.add(d);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _c.weekdays.contains(d)
                                ? const Color(0xFF007AFF)
                                : const Color(0xFFE9E9EB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            kWeekdayCodes[d - 1],
                            style: TextStyle(
                              fontSize: 13,
                              color: _c.weekdays.contains(d)
                                  ? CupertinoColors.white
                                  : CupertinoColors.black,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (_c.freq == kFreqMonthly)
                _DialogSwitchRow(
                  switchKey: const Key('recurrence_monthly_same_day'),
                  title: '每月同日',
                  value: _c.monthlyByDayOfMonth,
                  onChanged: (v) => setState(() => _c.monthlyByDayOfMonth = v),
                ),
              if (_c.freq == kFreqMonthly && !_c.monthlyByDayOfMonth)
                Row(
                  children: [
                    CupertinoButton(
                      key: const Key('recurrence_ordinal'),
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      onPressed: _pickOrdinal,
                      child: Text(
                        _c.ordinal == -1 ? '最后' : '第 ${_c.ordinal}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.systemBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      key: const Key('recurrence_ordinal_weekday'),
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      onPressed: _pickOrdinalWeekday,
                      child: Text(
                        kWeekdayCodes[_c.ordinalWeekday - 1],
                        style: const TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.systemBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              const _EditorLabel('结束'),
              CupertinoSlidingSegmentedControl<String>(
                key: const Key('recurrence_end'),
                groupValue: _endMode,
                children: const {
                  'never': Text('永不'),
                  'until': Text('日期'),
                  'count': Text('次数'),
                },
                onValueChanged: (v) => setState(() {
                  _c.count = v == 'count' ? (_c.count ?? 10) : null;
                  _c.until = v == 'until'
                      ? (_c.until ??
                            widget.startAt.toUtc().add(
                              const Duration(days: 30),
                            ))
                      : null;
                }),
              ),
              if (_c.count != null) ...[
                const _EditorLabel('次数'),
                CupertinoTextField(
                  key: const Key('recurrence_count'),
                  controller: _count,
                  keyboardType: TextInputType.number,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9E9EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  onChanged: (v) => _c.count = int.tryParse(v),
                ),
              ],
              if (_c.until != null)
                GestureDetector(
                  key: const Key('recurrence_until'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _pickUntil,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('结束日期', style: TextStyle(fontSize: 15)),
                        ),
                        Text(
                          '${_c.until!.year}-${_c.until!.month}-${_c.until!.day}',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          key: const Key('recurrence_editor_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          key: const Key('recurrence_editor_save'),
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(_c),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

/// 编辑器分组标签。
class _EditorLabel extends StatelessWidget {
  const _EditorLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
      ),
    );
  }
}

/// 对话框内开关行。
class _DialogSwitchRow extends StatelessWidget {
  const _DialogSwitchRow({
    required this.switchKey,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: switchKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15))),
            CupertinoSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// 提醒全量拷贝（kernel 无 copyWith；表单/Inspector 共用）。
CalendarEvent copyEventWithAlerts(CalendarEvent e, List<EventAlert> alerts) =>
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
  late final String _time =
      widget.initial
          .firstWhere(
            (a) => a.allDayTime != null,
            orElse: () => EventAlert(allDayTime: widget.allDayTime),
          )
          .allDayTime ??
      widget.allDayTime;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      key: const Key('alerts_dialog'),
      title: const Text('提醒'),
      content: SizedBox(
        height: 420,
        width: double.maxFinite,
        child: widget.allDay ? _buildAllDay() : _buildTimed(),
      ),
      actions: [
        CupertinoDialogAction(
          key: const Key('alerts_dialog_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          key: const Key('alerts_dialog_save'),
          isDefaultAction: true,
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
          _AlertRow(
            rowKey: Key('alert_timed_$offset'),
            title: timedAlertLabel(offset),
            checked: _timed.contains(offset),
            onToggle: () => setState(() {
              if (_timed.contains(offset)) {
                _timed.remove(offset);
              } else {
                _timed.add(offset);
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
          _AlertRow(
            rowKey: Key('alert_allday_$days'),
            title: allDayAlertLabel(days, _time),
            checked: _days.contains(days),
            onToggle: () => setState(() {
              if (_days.contains(days)) {
                _days.remove(days);
              } else {
                _days.add(days);
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

/// 提醒勾选行（整行 key 供测试 tap；整行可点切换）。
class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.rowKey,
    required this.title,
    required this.checked,
    required this.onToggle,
  });

  final Key rowKey;
  final String title;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: rowKey,
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(width: 0.5, color: CupertinoColors.separator),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            CupertinoCheckbox(value: checked, onChanged: (_) => onToggle()),
          ],
        ),
      ),
    );
  }
}
