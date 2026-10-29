import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_core/app_core.dart';
import 'package:app_ui/app_ui.dart';

import '../providers.dart';
import '../design/calendar_tokens.dart';
import '../logic/event_time.dart';
import '../logic/local_holidays.dart';
import 'calendar_shortcuts.dart';
import 'mini_month.dart';
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
  /// 当前获得焦点的日历行（#360）：空格切换的是它——Apple 的「选中行 + 空格切显隐」。
  String? _focusedCalendarId;

  @override
  Widget build(BuildContext context) {
    final calendarsAsync = ref.watch(calendarsProvider);
    final calendars = calendarsAsync.value ?? const <Calendar>[];
    final groups = _group(calendars);
    return Shortcuts(
      shortcuts: sidebarShortcutBindings(),
      child: Actions(
        actions: {
          // #360：此前只挂了 Shortcuts、**没有 Actions**——空格触发的
          // ToggleCalendarVisibilityIntent 无人处理，等于空操作。
          ToggleCalendarVisibilityIntent: CallbackAction<
              ToggleCalendarVisibilityIntent>(
            onInvoke: (_) {
              final id = _focusedCalendarId;
              if (id == null) return null;
              ref.read(calendarRepositoryProvider).setVisibility(
                    id: id,
                    visible: !(
                      ref
                          .read(calendarsProvider)
                          .value
                          ?.firstWhere((c) => c.id == id,
                              orElse: () => const Calendar(
                                  id: '', title: '', colorArgb: 0))
                          .isVisible ??
                      false
                    ),
                  );
              return null;
            },
          ),
        },
        child: SizedBox(
        key: const Key('calendar_sidebar'),
        width: widget.width,
        child: ColoredBox(
          // #295：ColoredBox 不会解算 CupertinoDynamicColor，直接把令牌的
          // 亮色档画出来——暗色档下整条侧栏就成了「黑主区 + 白侧栏」。
          color: CalendarTokens.groupedBackground.resolveFrom(context),
          // #383：Apple 侧栏的迷你月历是**底部固定**的，不跟着列表滚走。
          // 挂在 ListView 里会把「添加日历」等操作挤出视口（既有测试点不到它，
          // 真机上也要滚到底才看得见）——所以改成 Column + Expanded。
          child: Column(
            children: [
              Expanded(
                child: ListView(
            children: [
              for (final entry in groups.entries) ...[
                LifeSectionHeader(
                  title: entry.key,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                ),
                for (final c in entry.value) _CalendarRow(calendar: c, onFocused: (id) => _focusedCalendarId = id),
              ],
              // F-15：「其他」组固定行——已安排的提醒事项（默认勾选）
              _SidebarToggleRow(
                rowKey: const Key('sidebar_scheduled_reminders'),
                leading: const Icon(
                  CupertinoIcons.circle,
                  size: 18,
                  color: CalendarTokens.labelSecondary,
                ),
                title: '已安排的提醒事项',
                value: ref.watch(scheduledRemindersVisibleProvider),
                onChanged: (v) =>
                    ref.read(scheduledRemindersVisibleProvider.notifier).set(v),
              ),
              // F-16：本地节假日开关（lunar 生成，可关）
              // parity#204：与同列其它日历行保持同一控件（勾选框）与同一列，
              // 不再用开关。
              //
              // #281：节假日日历一旦存在，就会作为普通日历出现在「其他」分组里
              // （同一本日历、同一个勾选框）。此时这条固定行若还渲染，侧栏就会
              // 出现两行同名条目、状态还可能不同步。因此**仅在尚未订阅时**显示
              // 它作为入口；订阅后由分组内的同构行接管。
              if (calendars.every((c) => c.id != kHolidayCalendarId))
                _SidebarToggleRow(
                rowKey: const Key('sidebar_holidays_toggle'),
                leading: const Icon(
                  CupertinoIcons.calendar_badge_minus,
                  size: 18,
                  color: CalendarTokens.labelSecondary,
                ),
                title: '中国大陆节假日',
                value:
                    calendars
                        .where((c) => c.id == kHolidayCalendarId)
                        .firstOrNull
                        ?.isVisible ??
                    false,
                onChanged: (v) async {
                  final repo = ref.read(calendarRepositoryProvider);
                  if (v) {
                    await ensureLocalHolidayCalendar(
                      repo,
                      year: DateTime.now().year,
                      // #182：按设备时区落库，避免 UTC 墙钟把节日挪到前一天
                      timeZone: await deviceTimeZoneName(),
                    );
                  } else {
                    await repo.setVisibility(
                      id: kHolidayCalendarId,
                      visible: false,
                    );
                  }
                },
              ),
              // F-16：订阅占位（只存 URL，不发 HTTP）
              _SidebarActionRow(
                rowKey: const Key('sidebar-add-subscription'),
                icon: CupertinoIcons.link,
                label: '添加订阅',
                onPressed: () => showLocalSubscriptionDialog(
                  context,
                  repository: ref.read(calendarRepositoryProvider),
                ),
              ),
              const _Hairline(indent: 16),
              _SidebarActionRow(
                rowKey: const Key('sidebar-add-calendar'),
                icon: CupertinoIcons.plus,
                label: '添加日历',
                onPressed: () => _openAddDialog(context),
              ),
            ],
                ),
              ),
              const _Hairline(indent: 16),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: SizedBox(
                  height: 252,
                  child: MiniMonth(
                    key: Key('calendar_sidebar_mini_month'),
                    compact: true,
                  ),
                ),
              ),
            ],
          ),
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
    final created = await showCupertinoDialog<Calendar>(
      context: context,
      builder: (_) => const _CalendarEditDialog(),
    );
    if (created != null) {
      await ref.read(calendarRepositoryProvider).upsertCalendar(created);
    }
  }
}

class _CalendarRow extends ConsumerWidget {
  const _CalendarRow({required this.calendar, this.onFocused});

  final Calendar calendar;

  /// 行获得焦点时通知侧栏（空格切换的目标，见 #360）。
  final ValueChanged<String>? onFocused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(calendar.colorArgb);
    return Focus(
      onFocusChange: (has) {
        if (has) onFocused?.call(calendar.id);
      },
      child: Padding(
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
                CalendarKind.subscription => CupertinoIcons.globe,
                CalendarKind.shared => CupertinoIcons.person_2,
                CalendarKind.holiday => CupertinoIcons.gift,
                CalendarKind.local => CupertinoIcons.calendar,
              },
              size: 16,
              color: CalendarTokens.labelSecondary,
            ),
            if (calendar.lastRefreshError != null) ...[
              const SizedBox(width: 6),
              Icon(
                CupertinoIcons.exclamationmark_circle,
                key: Key('cal-refresh-error-${calendar.id}'),
                semanticLabel: '刷新失败',
                size: 14,
                color: CupertinoColors.systemRed.resolveFrom(context),
              ),
            ],
            const SizedBox(width: 6),
            Expanded(
              child: Text(calendar.title, overflow: TextOverflow.ellipsis),
            ),
            CupertinoButton(
              key: Key('cal-info-${calendar.id}'),
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              onPressed: () => _openDetail(context, ref),
              child: const Icon(
                CupertinoIcons.info,
                size: 16,
                color: CalendarTokens.labelSecondary,
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: CupertinoCheckbox(
                  key: Key('cal-visibility-${calendar.id}'),
                  value: calendar.isVisible,
                  onChanged: (v) => _onVisibilityTap(ref, v),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// 显隐点击（#360，Apple C-133）：
  /// - **⌘点** → 全部显隐（`allVisible`）；
  /// - **⌥⌘点** → 只留这一本（`onlyId`）；
  /// - 无修饰 → 单条勾选（既有行为）。
  ///
  /// 此前 A7 行裁「对等」，但仓储 API 备好、界面上按不出来（lib 里没有修饰键检测）。
  Future<void> _onVisibilityTap(WidgetRef ref, bool? v) async {
    final keys = HardwareKeyboard.instance;
    final repo = ref.read(calendarRepositoryProvider);
    if (keys.isMetaPressed && keys.isAltPressed) {
      await repo.setVisibility(onlyId: calendar.id);
      return;
    }
    if (keys.isMetaPressed) {
      // ⌘点：把**全部**日历切到与本条相反的状态（Apple「⌘点全选/全不选」语义）。
      await repo.setVisibility(allVisible: !calendar.isVisible);
      return;
    }
    await repo.setVisibility(id: calendar.id, visible: v ?? true);
  }

  /// TC-CAL-UI-127：详情 ⓘ——改色、忽略提醒、删除。
  Future<void> _openDetail(BuildContext context, WidgetRef ref) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => _CalendarDetailDialog(calendar: calendar),
    );
  }
}

/// 侧栏开关行（复选/开关两形态）。
class _SidebarToggleRow extends StatelessWidget {
  const _SidebarToggleRow({
    required this.rowKey,
    required this.title,
    required this.value,
    required this.onChanged,
    this.leading,
  });

  final Key rowKey;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // #281 顺带修正：rowKey 此前只存字段、没挂到 widget，等于键位不存在
      key: rowKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          if (leading != null) ...[const SizedBox(width: 12), leading!],
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
          SizedBox(
            height: 32,
            child: Center(
              // parity#204：同列表统一用勾选框（开关只留给详情页的「忽略提醒」）
              child: CupertinoCheckbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// 侧栏动作行（图标 + 文案）。
class _SidebarActionRow extends StatelessWidget {
  const _SidebarActionRow({
    required this.rowKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key rowKey;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      key: rowKey,
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 16, color: CupertinoColors.systemBlue),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemBlue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Apple 式 0.5px 发丝分隔线。
class _Hairline extends StatelessWidget {
  const _Hairline({this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(
        height: 0.5,
        color: CupertinoColors.separator.resolveFrom(context),
      ),
    );
  }
}

/// 详情对话框（TC-CAL-UI-120/121/127 共用编辑体；添加时 title 为空起始）。
class _CalendarEditDialog extends ConsumerStatefulWidget {
  const _CalendarEditDialog({this.calendar});

  final Calendar? calendar;

  @override
  ConsumerState<_CalendarEditDialog> createState() =>
      _CalendarEditDialogState();
}

class _CalendarEditDialogState extends ConsumerState<_CalendarEditDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.calendar?.title ?? '',
  );
  late int _colorArgb =
      widget.calendar?.colorArgb ?? kCalendarPresetColors[4].$2; // 默认蓝
  late bool _ignoreAlerts = widget.calendar?.ignoreAlerts ?? false;

  void _persist() {
    final existing = widget.calendar;
    if (existing == null) {
      return; // 新建态由「完成」统一提交
    }
    ref
        .read(calendarRepositoryProvider)
        .upsertCalendar(
          Calendar(
            id: existing.id,
            remoteId: existing.remoteId,
            title: _title.text.trim().isEmpty
                ? existing.title
                : _title.text.trim(),
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
            lastRefreshError: existing.lastRefreshError,
            permission: existing.permission,
            revision: existing.revision,
            deletedAt: existing.deletedAt,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.calendar != null;
    return LifeAlertDialog(
      title: Text(isEdit ? '编辑日历' : '添加日历'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _title,
            placeholder: '名称',
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final (_, argb) in kCalendarPresetColors)
                GestureDetector(
                  key: Key(
                    'preset-color-0x${argb.toRadixString(16).toUpperCase()}',
                  ),
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
                      // label 而不是 CupertinoColors.black：black 是 const Color、
                      // 没有暗档，暗色档下黑环贴深色弹层底＝选中态直接丢了。
                      border: _colorArgb == argb
                          ? Border.all(
                              width: 3,
                              color: CupertinoColors.label.resolveFrom(context),
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          if (isEdit) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('忽略提醒', style: TextStyle(fontSize: 14)),
                ),
                CupertinoSwitch(
                  key: const Key('detail-ignore-alerts'),
                  value: _ignoreAlerts,
                  onChanged: (v) {
                    setState(() => _ignoreAlerts = v);
                    _persist(); // 侧栏编辑即时生效（TC-CAL-UI-127）
                  },
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        if (isEdit)
          LifeDialogAction(
            key: const Key('detail-delete'),
            isDestructiveAction: true,
            onPressed: () async {
              await ref
                  .read(calendarRepositoryProvider)
                  .deleteCalendar(widget.calendar!.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('删除'),
          ),
        LifeDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        LifeDialogAction(
          key: const Key('dialog-done'),
          isDefaultAction: true,
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
