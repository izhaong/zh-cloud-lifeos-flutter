/// 日历设置面板（契约 §2.9；F-14）。
///
/// 四个区：通用 / 提醒 / 高级 / 账户；每项改动立即写 CalendarPreference
/// 并 `savePreference`（未登录时由仓库落本地，键 lifeos.calendar.pref.*）。
/// Cupertino 化（#130）：底部弹层 + 行式开关 + ActionSheet 下拉。
library;

import '../design/calendar_tokens.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/preference_copy.dart';
import '../providers.dart';
import 'package:app_core/app_core.dart';
import 'package:app_ui/app_ui.dart';

Future<void> showCalendarSettingsSheet(BuildContext context) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: CalendarSettingsSheet(),
    ),
  );
}

class CalendarSettingsSheet extends ConsumerStatefulWidget {
  const CalendarSettingsSheet({super.key});

  @override
  ConsumerState<CalendarSettingsSheet> createState() =>
      _CalendarSettingsSheetState();
}

class _CalendarSettingsSheetState extends ConsumerState<CalendarSettingsSheet> {
  /// 用户本次会话内改过的值；null = 跟随仓库流（首帧流可能仍在 loading）。
  CalendarPreference? _local;

  void _save(CalendarPreference next) {
    setState(() => _local = next);
    ref.read(calendarRepositoryProvider).savePreference(next);
  }

  /// ActionSheet 下拉（选项含 null 项时 null 也是合法取值）。
  Future<T?> _pick<T>(Map<T, String> items, T value) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => LifeActionSheet(
        actions: [
          for (final e in items.entries)
            LifeActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(e.key),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (e.key == value) ...[
                    const Icon(CupertinoIcons.checkmark, size: 16),
                    const SizedBox(width: 4),
                  ],
                  Text(e.value),
                ],
              ),
            ),
        ],
        cancelButton: LifeActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pref =
        _local ??
        ref.watch(preferenceProvider).value ??
        CalendarPreference.defaults;
    return ColoredBox(
      key: const Key('calendar_settings_sheet'),
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const LifeSectionHeader(
              title: '通用',
              key: Key('settings_section_general'),
            ),
            _dropdown<int>(
              key: const Key('settings_start_week_on'),
              title: '每周起始',
              value: pref.startWeekOn,
              items: const {1: '周一', 7: '周日'},
              onChanged: (v) =>
                  _save(copyCalendarPreference(pref, startWeekOn: v)),
            ),
            _dropdown<int>(
              key: const Key('settings_week_view_days'),
              title: '每周显示天数',
              value: pref.weekViewDays,
              items: const {7: '7 天', 5: '周一至周五'},
              onChanged: (v) =>
                  _save(copyCalendarPreference(pref, weekViewDays: v)),
            ),
            _dropdown<int>(
              key: const Key('settings_day_start_hour'),
              title: '一天开始',
              value: pref.dayStartHour,
              items: {
                for (var h = 0; h <= 12; h++)
                  h: '${h.toString().padLeft(2, '0')}:00',
              },
              onChanged: (v) =>
                  _save(copyCalendarPreference(pref, dayStartHour: v)),
            ),
            _dropdown<int>(
              key: const Key('settings_day_end_hour'),
              title: '一天结束',
              value: pref.dayEndHour,
              items: {
                for (var h = 6; h <= 23; h++)
                  h: '${h.toString().padLeft(2, '0')}:00',
              },
              onChanged: (v) =>
                  _save(copyCalendarPreference(pref, dayEndHour: v)),
            ),
            _SwitchRow(
              key: const Key('settings_show_week_numbers'),
              title: '显示周数',
              value: pref.showWeekNumbers,
              onChanged: (v) =>
                  _save(copyCalendarPreference(pref, showWeekNumbers: v)),
            ),
            _SwitchRow(
              key: const Key('settings_alternate_calendar'),
              title: '备用历法（农历）',
              value: pref.alternateCalendar == AlternateCalendar.chinese,
              onChanged: (v) => _save(
                copyCalendarPreference(
                  pref,
                  alternateCalendar: v
                      ? AlternateCalendar.chinese
                      : AlternateCalendar.none,
                ),
              ),
            ),
            _SwitchRow(
              key: const Key('settings_show_holidays'),
              title: '显示节假日',
              value: pref.showHolidays,
              onChanged: (v) =>
                  _save(copyCalendarPreference(pref, showHolidays: v)),
            ),
            const LifeSectionHeader(
              title: '提醒',
              key: Key('settings_section_reminders'),
            ),
            _dropdown<int?>(
              key: const Key('settings_default_alert_timed'),
              title: '默认提醒（定时日程）',
              value: pref.defaultAlertTimedMinutes,
              items: const {
                null: '无',
                0: '日程开始时',
                -5: '5 分钟前',
                -15: '15 分钟前',
                -30: '30 分钟前',
                -60: '1 小时前',
              },
              onChanged: (v) => _save(
                copyCalendarPreference(
                  pref,
                  defaultAlertTimedMinutes: v,
                  clearDefaultAlertTimed: v == null,
                ),
              ),
            ),
            _dropdown<int?>(
              key: const Key('settings_default_alert_allday'),
              title: '默认提醒（全天日程）',
              value: pref.defaultAlertAllDayDays,
              items: const {
                null: '无',
                0: '当天 09:00',
                1: '前一天 09:00',
                2: '前两天 09:00',
                7: '前一周 09:00',
              },
              onChanged: (v) => _save(
                copyCalendarPreference(
                  pref,
                  defaultAlertAllDayDays: v,
                  clearDefaultAlertAllDayDays: v == null,
                ),
              ),
            ),
            _dropdown<int>(
              key: const Key('settings_default_duration'),
              title: '新日程时长',
              value: pref.defaultDurationMinutes,
              items: const {15: '15 分钟', 30: '30 分钟', 60: '1 小时', 120: '2 小时'},
              onChanged: (v) => _save(
                copyCalendarPreference(pref, defaultDurationMinutes: v),
              ),
            ),
            const LifeSectionHeader(
              title: '高级',
              key: Key('settings_section_advanced'),
            ),
            _SwitchRow(
              key: const Key('settings_time_zone_support'),
              title: '时区支持',
              subtitle: '开启后日程表单显示浮动时间',
              value: pref.timeZoneSupport,
              onChanged: (v) =>
                  _save(copyCalendarPreference(pref, timeZoneSupport: v)),
            ),
            _Row(
              key: const Key('settings_display_time_zone'),
              title: '显示时区',
              trailing: Text(
                pref.timeZoneSupport ? (pref.displayTimeZone ?? '跟随设备') : '未开启',
                style: const TextStyle(fontSize: 15),
              ),
            ),
            _SwitchRow(
              key: const Key('settings_open_in_window'),
              title: '在独立窗口打开日程',
              value: pref.openEventsInWindow,
              onChanged: (v) =>
                  _save(copyCalendarPreference(pref, openEventsInWindow: v)),
            ),
            const LifeSectionHeader(
              title: '账户',
              key: Key('settings_section_account'),
            ),
            const _Row(
              key: Key('settings_account_note'),
              title: '未登录，数据只在本机',
              subtitle: '登录后可在多设备同步（F-17）',
            ),
            if (ref.watch(calendarSyncTriggerProvider) != null)
              _Row(
                key: const Key('settings_sync_now'),
                title: '立即同步',
                trailing: CupertinoButton(
                  key: const Key('settings_sync_now_button'),
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    await ref.read(calendarSyncTriggerProvider)?.call();
                  },
                  child: const Text('同步'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required Key key,
    required String title,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) {
    return _Row(
      key: key,
      title: title,
      onTap: () async {
        final v = await _pick<T>(items, value);
        if (v != null || items.containsKey(null)) {
          onChanged(v as T);
        }
      },
      trailing: Text(items[value] ?? '无', style: const TextStyle(fontSize: 15)),
    );
  }
}

/// 设置行：标题（+副标题）+ 可收缩 trailing + 底部细线；整行可点。
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CalendarTokens.labelSecondary,
                      ),
                    ),
                ],
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

/// 开关行（整行 key 供测试 tap）。
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                        color: CalendarTokens.labelSecondary,
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

