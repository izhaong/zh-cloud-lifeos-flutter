/// 日历设置面板（契约 §2.9；F-14）。
///
/// 四个区：通用 / 提醒 / 高级 / 账户；每项改动立即写 CalendarPreference
/// 并 `savePreference`（未登录时由仓库落本地，键 lifeos.calendar.pref.*）。
library;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/preference_copy.dart';
import '../providers.dart';

Future<void> showCalendarSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
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

  @override
  Widget build(BuildContext context) {
    final pref = _local ??
        ref.watch(preferenceProvider).value ??
        CalendarPreference.defaults;
    return Material(
      key: const Key('calendar_settings_sheet'),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader(title: '通用', key: Key('settings_section_general')),
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
            items: {for (var h = 0; h <= 12; h++) h: '${h.toString().padLeft(2, '0')}:00'},
            onChanged: (v) =>
                _save(copyCalendarPreference(pref, dayStartHour: v)),
          ),
          _dropdown<int>(
            key: const Key('settings_day_end_hour'),
            title: '一天结束',
            value: pref.dayEndHour,
            items: {for (var h = 6; h <= 23; h++) h: '${h.toString().padLeft(2, '0')}:00'},
            onChanged: (v) =>
                _save(copyCalendarPreference(pref, dayEndHour: v)),
          ),
          SwitchListTile(
            key: const Key('settings_show_week_numbers'),
            title: const Text('显示周数'),
            value: pref.showWeekNumbers,
            onChanged: (v) =>
                _save(copyCalendarPreference(pref, showWeekNumbers: v)),
          ),
          SwitchListTile(
            key: const Key('settings_alternate_calendar'),
            title: const Text('备用历法（农历）'),
            value: pref.alternateCalendar == AlternateCalendar.chinese,
            onChanged: (v) => _save(copyCalendarPreference(pref,
                alternateCalendar:
                    v ? AlternateCalendar.chinese : AlternateCalendar.none)),
          ),
          SwitchListTile(
            key: const Key('settings_show_holidays'),
            title: const Text('显示节假日'),
            value: pref.showHolidays,
            onChanged: (v) =>
                _save(copyCalendarPreference(pref, showHolidays: v)),
          ),
          const _SectionHeader(title: '提醒', key: Key('settings_section_reminders')),
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
            onChanged: (v) => _save(copyCalendarPreference(pref,
                defaultAlertTimedMinutes: v,
                clearDefaultAlertTimed: v == null)),
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
            onChanged: (v) => _save(copyCalendarPreference(pref,
                defaultAlertAllDayDays: v,
                clearDefaultAlertAllDayDays: v == null)),
          ),
          _dropdown<int>(
            key: const Key('settings_default_duration'),
            title: '新日程时长',
            value: pref.defaultDurationMinutes,
            items: const {15: '15 分钟', 30: '30 分钟', 60: '1 小时', 120: '2 小时'},
            onChanged: (v) =>
                _save(copyCalendarPreference(pref, defaultDurationMinutes: v)),
          ),
          const _SectionHeader(title: '高级', key: Key('settings_section_advanced')),
          SwitchListTile(
            key: const Key('settings_time_zone_support'),
            title: const Text('时区支持'),
            subtitle: const Text('开启后日程表单显示浮动时间'),
            value: pref.timeZoneSupport,
            onChanged: (v) =>
                _save(copyCalendarPreference(pref, timeZoneSupport: v)),
          ),
          ListTile(
            key: const Key('settings_display_time_zone'),
            title: const Text('显示时区'),
            trailing: Text(pref.timeZoneSupport ? (pref.displayTimeZone ?? '跟随设备') : '未开启'),
          ),
          SwitchListTile(
            key: const Key('settings_open_in_window'),
            title: const Text('在独立窗口打开日程'),
            value: pref.openEventsInWindow,
            onChanged: (v) =>
                _save(copyCalendarPreference(pref, openEventsInWindow: v)),
          ),
          const _SectionHeader(title: '账户', key: Key('settings_section_account')),
          const ListTile(
            key: Key('settings_account_note'),
            title: Text('未登录，数据只在本机'),
            subtitle: Text('登录后可在多设备同步（F-17）'),
          ),
          if (ref.watch(calendarSyncTriggerProvider) != null)
            ListTile(
              key: const Key('settings_sync_now'),
              title: const Text('立即同步'),
              trailing: TextButton(
                key: const Key('settings_sync_now_button'),
                onPressed: () async {
                  await ref.read(calendarSyncTriggerProvider)?.call();
                },
                child: const Text('同步'),
              ),
            ),
        ],
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
    return ListTile(
      key: key,
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        items: [
          for (final e in items.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) {
          if (v != null || items.containsKey(null)) {
            onChanged(v as T);
          }
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF8E8E93),
            ),
      ),
    );
  }
}
