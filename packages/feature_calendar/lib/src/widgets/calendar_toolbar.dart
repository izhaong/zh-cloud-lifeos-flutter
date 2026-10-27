import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'calendar_settings_sheet.dart';

/// 日历工具栏（契约 §5.4/§8.5）。
///
/// compact（<600，iPhone）：‹年月标题› ‹ › 搜索 ＋；
/// medium/expanded：＋ | 日历列表切换 | 日/周/月/年 分段 | ‹ 今天 › | 收件箱 | 搜索。
///
/// F-03 骨架：结构与 Key 就位（`calendar_toolbar`）；＋→F-12、列表切换→F-04、
/// 收件箱→M4、搜索→F-13 的行为随后续卡接入。
class CalendarToolbar extends ConsumerWidget {
  const CalendarToolbar({
    super.key,
    this.compact = false,
    this.onQuickCreate,
    this.onQuickCreateReminder,
  });

  /// 宽度 <600（iPhone 档）时用精简形态（契约 §8.5）。
  final bool compact;

  /// 「＋」→ 新建日程（F-12；由 scaffold 注入）。
  final VoidCallback? onQuickCreate;

  /// 「＋」→ 新建提醒（F-15；由 scaffold 注入）。
  final VoidCallback? onQuickCreateReminder;

  static const _labels = {
    CalendarViewMode.day: '日',
    CalendarViewMode.week: '周',
    CalendarViewMode.month: '月',
    CalendarViewMode.year: '年',
    CalendarViewMode.list: '列表',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(searchActiveProvider)) {
      return const _CalendarSearchBar();
    }
    final anchor = ref.watch(anchorDateProvider);
    final toolbar = compact
        ? Row(
            children: [
              const SizedBox(width: 4),
              Text(
                '${anchor.year}年${anchor.month}月',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _ToolbarIconButton(
                tooltip: '上一个月',
                icon: CupertinoIcons.chevron_left,
                onPressed: () => _shift(ref, -1),
              ),
              _ToolbarIconButton(
                tooltip: '下一个月',
                icon: CupertinoIcons.chevron_right,
                onPressed: () => _shift(ref, 1),
              ),
              const Spacer(),
              _ToolbarIconButton(
                key: const Key('calendar_search_button'),
                tooltip: '搜索',
                icon: CupertinoIcons.search,
                onPressed: () =>
                    ref.read(searchActiveProvider.notifier).set(true),
              ),
              _QuickCreateButton(
                onEvent: onQuickCreate,
                onReminder: onQuickCreateReminder,
              ),
            ],
          )
        : Row(
            children: [
              _QuickCreateButton(
                onEvent: onQuickCreate,
                onReminder: onQuickCreateReminder,
              ),
              _ToolbarIconButton(
                tooltip: '日历列表',
                icon: CupertinoIcons.sidebar_left,
                onPressed: () =>
                    ref.read(sidebarVisibleProvider.notifier).toggle(),
              ),
              const SizedBox(width: 8),
              const Expanded(child: _ViewSegment()),
              _ToolbarIconButton(
                tooltip: '上一天/周/月/年',
                icon: CupertinoIcons.chevron_left,
                onPressed: () => _shift(ref, -1),
              ),
              CupertinoButton(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: () => ref.read(anchorDateProvider.notifier).today(),
                child: const Text('今天'),
              ),
              _ToolbarIconButton(
                tooltip: '下一天/周/月/年',
                icon: CupertinoIcons.chevron_right,
                onPressed: () => _shift(ref, 1),
              ),
              _ToolbarIconButton(
                key: const Key('calendar_inbox_button'),
                tooltip: '收件箱',
                icon: CupertinoIcons.tray_full,
                onPressed: () =>
                    ref.read(calendarInboxOpenerProvider)?.call(context),
              ),
              _ToolbarIconButton(
                key: const Key('calendar_settings_button'),
                tooltip: '设置',
                icon: CupertinoIcons.gear,
                onPressed: () => showCalendarSettingsSheet(context),
              ),
              _ToolbarIconButton(
                key: const Key('calendar_search_button'),
                tooltip: '搜索',
                icon: CupertinoIcons.search,
                onPressed: () =>
                    ref.read(searchActiveProvider.notifier).set(true),
              ),
            ],
          );
    return Container(
      key: const Key('calendar_toolbar'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: toolbar,
    );
  }

  void _shift(WidgetRef ref, int direction) {
    final anchor = ref.read(anchorDateProvider);
    final mode = ref.read(viewModeProvider);
    final next = switch (mode) {
      CalendarViewMode.day ||
      CalendarViewMode.list ||
      CalendarViewMode.week => anchor.add(
        Duration(days: direction * (mode == CalendarViewMode.week ? 7 : 1)),
      ),
      CalendarViewMode.month => DateTime(
        anchor.year,
        anchor.month + direction,
        anchor.day,
      ),
      CalendarViewMode.year => DateTime(
        anchor.year + direction,
        anchor.month,
        anchor.day,
      ),
    };
    ref.read(anchorDateProvider.notifier).set(next);
  }
}

/// 工具栏图标按钮（0.5px 风格：无涟漪、系统蓝）。
class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        onPressed: onPressed,
        child: Icon(icon, size: 22, color: CupertinoColors.systemBlue),
      ),
    );
  }
}

class _ViewSegment extends ConsumerWidget {
  const _ViewSegment();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const modes = [
      CalendarViewMode.day,
      CalendarViewMode.week,
      CalendarViewMode.month,
      CalendarViewMode.year,
    ];
    final mode = ref.watch(viewModeProvider);
    return CupertinoSlidingSegmentedControl<CalendarViewMode>(
      groupValue: mode == CalendarViewMode.list ? null : mode,
      onValueChanged: (value) {
        if (value != null) {
          ref.read(viewModeProvider.notifier).set(value);
        }
      },
      children: {for (final m in modes) m: Text(CalendarToolbar._labels[m]!)},
    );
  }
}

/// 搜索框（⌘F / 放大镜展开；F-13 TC-CAL-UI-171）。
class _CalendarSearchBar extends ConsumerStatefulWidget {
  const _CalendarSearchBar();

  @override
  ConsumerState<_CalendarSearchBar> createState() => _CalendarSearchBarState();
}

class _CalendarSearchBarState extends ConsumerState<_CalendarSearchBar> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(searchQueryProvider),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('calendar_toolbar'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              key: const Key('calendar_search_field'),
              controller: _controller,
              autofocus: true,
              placeholder: '搜索日程（标题/地点/备注）',
              decoration: const BoxDecoration(),
              onChanged: (v) => ref.read(searchQueryProvider.notifier).set(v),
            ),
          ),
          CupertinoButton(
            key: const Key('calendar_search_close'),
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            onPressed: () {
              _controller.clear();
              ref.read(searchQueryProvider.notifier).set('');
              ref.read(searchActiveProvider.notifier).set(false);
            },
            child: const Icon(
              CupertinoIcons.xmark,
              size: 22,
              color: CupertinoColors.systemBlue,
            ),
          ),
        ],
      ),
    );
  }
}

/// 「＋」下拉：日程 / 提醒（F-15）。
class _QuickCreateButton extends StatelessWidget {
  const _QuickCreateButton({this.onEvent, this.onReminder});

  final VoidCallback? onEvent;
  final VoidCallback? onReminder;

  @override
  Widget build(BuildContext context) {
    return CupertinoMenuAnchor(
      menuChildren: [
        CupertinoMenuItem(
          key: const Key('quick_create_event'),
          onPressed: onEvent == null ? null : () => onEvent!(),
          child: const Text('新建日程'),
        ),
        CupertinoMenuItem(
          key: const Key('quick_create_reminder'),
          onPressed: onReminder == null ? null : () => onReminder!(),
          child: const Text('新建提醒'),
        ),
      ],
      builder: (context, controller, child) {
        return Semantics(
          label: '新建',
          button: true,
          child: CupertinoButton(
            key: const Key('quick_create_menu'),
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            onPressed: controller.open,
            child: const Icon(
              CupertinoIcons.plus,
              size: 22,
              color: CupertinoColors.systemBlue,
            ),
          ),
        );
      },
    );
  }
}
