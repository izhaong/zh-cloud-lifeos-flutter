
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../logic/local_holidays.dart';
import 'calendar_shortcuts.dart';
import 'subscription_dialog.dart';

/// 日历侧栏（契约 §5.4/§8.5；F-04）。
///
/// 三组固定分组：「我的日历」（LOCAL）、「订阅」（SUBSCRIPTION）、「其他」（HOLIDAY/SHARED）。
/// 行：色点 + 名称 + 图标（shared/subscription 不同）+ 勾选；ⓘ 打开详情（改色/忽略提醒/删除）。
/// 底部「添加日历」。medium 档宽 240（≥1200 走 280 由外部容器控制），compact 档不使用（iPhone 月条）。
class CalendarSidebar extends ConsumerStatefulWidget {
  const CalendarSidebar({super.key, this.width = 240});

  /// medium=240、expanded=280（契约 §8.5）。
  final double width;

  @override
  ConsumerState<CalendarSidebar> createState() => _CalendarSidebarState();
}

class _CalendarSidebarState extends ConsumerState<CalendarSidebar> {
  @override
  Widget build(BuildContext context) {
    final calendarsAsync = ref.watch(calendarsProvider);
    final calendars = calendarsAsync.value ?? const <Calendar>[];
    final groups = _group(calendars);
    return Shortcuts(
      shortcuts: sidebarShortcutBindings(),
      child: SizedBox(
        key: const Key('calendar_sidebar'),
        width: widget.width,
        child: Material(
          color: const Color(0xFFF2F2F7),
          child: ListView(
            children: [
              for (final entry in groups.entries) ...[
                _GroupHeader(title: entry.key),
                for (final c in entry.value) _CalendarRow(calendar: c),
              ],
              // F-15：「其他」组固定行——已安排的提醒事项（默认勾选）
              CheckboxListTile(
                key: const Key('sidebar_scheduled_reminders'),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                secondary: const Icon(Icons.radio_button_unchecked, size: 18),
                title: const Text('已安排的提醒事项'),
                value: ref.watch(scheduledRemindersVisibleProvider),
                onChanged: (v) => ref
                    .read(scheduledRemindersVisibleProvider.notifier)
                    .set(v ?? true),
              ),
              // F-16：本地节假日开关（lunar 生成，可关）
              SwitchListTile(
                key: const Key('sidebar_holidays_toggle'),
                dense: true,
                title: const Text('中国大陆节假日'),
                value: calendars
                        .where((c) => c.id == kHolidayCalendarId)
                        .firstOrNull
                        ?.isVisible ??
                    false,
                onChanged: (v) async {
                  final repo = ref.read(calendarRepositoryProvider);
                  if (v) {
                    await ensureLocalHolidayCalendar(repo,
                        year: DateTime.now().year);
                  } else {
                    await repo.setVisibility(
                        id: kHolidayCalendarId, visible: false);
                  }
                },
              ),
              // F-16：订阅占位（只存 URL，不发 HTTP）
              TextButton.icon(
                key: const Key('sidebar-add-subscription'),
                onPressed: () => showLocalSubscriptionDialog(context,
                    repository: ref.read(calendarRepositoryProvider)),
                icon: const Icon(Icons.add_link),
                label: const Text('添加订阅'),
              ),
              const Divider(height: 1),
              TextButton.icon(
                key: const Key('sidebar-add-calendar'),
                onPressed: () => _openAddDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('添加日历'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 三组固定分组（TC-CAL-UI-122）；LOCAL 内按 groupName 再分组（TC-CAL-UI-123）。
  Map<String, List<Calendar>> _group(List<Calendar> calendars) {
    final linked = <String, List<Calendar>>{};
    final mine = <Calendar>[];
    final groupHeads = <String, List<Calendar>>{};
    final subs = <Calendar>[];
    final others = <Calendar>[];
    for (final c in calendars) {
      switch (c.kind) {
        case CalendarKind.local:
          if (c.groupName != null && c.groupName!.isNotEmpty) {
            groupHeads.putIfAbsent(c.groupName!, () => []).add(c);
          } else {
            mine.add(c);
          }
        case CalendarKind.subscription:
          subs.add(c);
        case CalendarKind.holiday || CalendarKind.shared:
          others.add(c);
      }
    }
    linked['我的日历'] = mine;
    for (final entry in groupHeads.entries) {
      linked[entry.key] = entry.value;
    }
    linked['订阅'] = subs;
    linked['其他'] = others;
    return linked;
  }

  Future<void> _openAddDialog(BuildContext context) async {
    final created = await showDialog<Calendar>(
      context: context,
      builder: (_) => const _CalendarEditDialog(),
    );
    if (created != null) {
      await ref.read(calendarRepositoryProvider).upsertCalendar(created);
    }
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: const Color(0xFF8E8E93))),
    );
  }
}

class _CalendarRow extends ConsumerWidget {
  const _CalendarRow({required this.calendar});

  final Calendar calendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(calendar.colorArgb);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Icon(
              switch (calendar.kind) {
                CalendarKind.subscription => Icons.rss_feed,
                CalendarKind.shared => Icons.group_outlined,
                CalendarKind.holiday => Icons.celebration_outlined,
                CalendarKind.local => Icons.event_note_outlined,
              },
              size: 16,
              color: const Color(0xFF8E8E93),
            ),
            if (calendar.lastRefreshError != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.error_outline,
                key: Key('cal-refresh-error-${calendar.id}'),
                semanticLabel: '刷新失败',
                size: 14,
                color: const Color(0xFFFF3B30),
              ),
            ],
            const SizedBox(width: 6),
            Expanded(
              child: Text(calendar.title, overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              key: Key('cal-info-${calendar.id}'),
              tooltip: '日历详情',
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.info_outline, size: 16),
              onPressed: () => _openDetail(context, ref),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                visualDensity: VisualDensity.compact,
                value: calendar.isVisible,
                onChanged: (v) => ref
                    .read(calendarRepositoryProvider)
                    .setVisibility(id: calendar.id, visible: v ?? true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// TC-CAL-UI-127：详情 ⓘ——改色、忽略提醒、删除。
  Future<void> _openDetail(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CalendarDetailDialog(calendar: calendar),
    );
  }
}

/// 详情对话框（TC-CAL-UI-120/121/127 共用编辑体；添加时 title 为空起始）。
class _CalendarEditDialog extends ConsumerStatefulWidget {
  const _CalendarEditDialog({this.calendar});

  final Calendar? calendar;

  @override
  ConsumerState<_CalendarEditDialog> createState() => _CalendarEditDialogState();
}

class _CalendarEditDialogState extends ConsumerState<_CalendarEditDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.calendar?.title ?? '');
  late int _colorArgb =
      widget.calendar?.colorArgb ?? kCalendarPresetColors[4].$2; // 默认蓝
  late bool _ignoreAlerts = widget.calendar?.ignoreAlerts ?? false;

  void _persist() {
    final existing = widget.calendar;
    if (existing == null) {
      return; // 新建态由「完成」统一提交
    }
    ref.read(calendarRepositoryProvider).upsertCalendar(Calendar(
          id: existing.id,
          remoteId: existing.remoteId,
          title: _title.text.trim().isEmpty ? existing.title : _title.text.trim(),
          colorArgb: _colorArgb,
          kind: existing.kind,
          groupName: existing.groupName,
          isVisible: existing.isVisible,
          isDefault: existing.isDefault,
          sortOrder: existing.sortOrder,
          ignoreAlerts: _ignoreAlerts,
          sourceUrl: existing.sourceUrl,
          refreshMinutes: existing.refreshMinutes,
          holidayRegion: existing.holidayRegion,
          permission: existing.permission,
          revision: existing.revision,
          deletedAt: existing.deletedAt,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.calendar != null;
    return AlertDialog(
      title: Text(isEdit ? '编辑日历' : '添加日历'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final (_, argb) in kCalendarPresetColors)
                  GestureDetector(
                    key: Key('preset-color-0x${argb.toRadixString(16).toUpperCase()}'),
                    onTap: () {
                      setState(() => _colorArgb = argb);
                      if (isEdit) {
                        _persist(); // 改色即时生效（TC-CAL-UI-121）
                      }
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(argb),
                        shape: BoxShape.circle,
                        border: _colorArgb == argb
                            ? Border.all(width: 3, color: Colors.black87)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            if (isEdit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('detail-ignore-alerts'),
                title: const Text('忽略提醒'),
                value: _ignoreAlerts,
                onChanged: (v) {
                  setState(() => _ignoreAlerts = v);
                  _persist(); // 侧栏编辑即时生效（TC-CAL-UI-127）
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (isEdit)
          TextButton(
            key: const Key('detail-delete'),
            onPressed: () async {
              await ref
                  .read(calendarRepositoryProvider)
                  .deleteCalendar(widget.calendar!.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('删除', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          key: const Key('dialog-done'),
          onPressed: () async {
            if (_title.text.trim().isEmpty) {
              return; // 名称必填
            }
            final repo = ref.read(calendarRepositoryProvider);
            final existing = widget.calendar;
            if (existing != null) {
              _persist();
              if (context.mounted) Navigator.of(context).pop(existing);
              return;
            }
            final target = Calendar(
              id: 'cal_${DateTime.now().microsecondsSinceEpoch}',
              title: _title.text.trim(),
              colorArgb: _colorArgb,
              kind: CalendarKind.local,
              isVisible: true,
              ignoreAlerts: _ignoreAlerts,
            );
            await repo.upsertCalendar(target);
            if (context.mounted) Navigator.of(context).pop(target);
          },
          child: const Text('完成'),
        ),
      ],
    );
  }
}

/// 详情 ⓘ 对话框（编辑态）。
class _CalendarDetailDialog extends StatelessWidget {
  const _CalendarDetailDialog({required this.calendar});

  final Calendar calendar;

  @override
  Widget build(BuildContext context) {
    return _CalendarEditDialog(calendar: calendar);
  }
}
