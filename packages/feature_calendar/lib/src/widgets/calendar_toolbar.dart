import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'calendar_settings_sheet.dart';

/// 日历工具栏（契约 §5.4/§8.5）。
///
/// compact（<600，iPhone）：‹年月标题› ‹ › 搜索 ＋；
/// medium/expanded：＋ | 日历列表切换 | 日/周/月/年/列表 分段 | ‹ 今天 › | 收件箱 | 搜索。
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
        // #627：一行拆成「标题＋翻档」和「菜单＋搜索＋新建」两组，中间用
        // spaceBetween 让位（原先的 Spacer 与标题抢同一段余量，标题一旦超出
        // 余量就没人能让，375 宽下「2026年10月」溢出 0.18px）。
        // 日档几何与拆组前逐像素相同：余量 33.8px 依旧全落在两组之间。
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 4),
                    _compactTitleText(
                      context,
                      _compactTitle(anchor, ref.watch(viewModeProvider)),
                    ),
                    _ToolbarIconButton(
                      tooltip: '上一页',
                      icon: CupertinoIcons.chevron_left,
                      onPressed: () => _shift(ref, -1),
                    ),
                    _ToolbarIconButton(
                      tooltip: '下一页',
                      icon: CupertinoIcons.chevron_right,
                      onPressed: () => _shift(ref, 1),
                    ),
                    CupertinoButton(
                      key: const Key('calendar_today_button'),
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: () =>
                          ref.read(anchorDateProvider.notifier).today(),
                      child: const Text('今天'),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _CompactViewModeMenu(),
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
                // #607：☰ 显式挂 Key，TC-CAL-UI-107 才从入口点得下去
                // （只有 provider 层断言拦不住组合根漏注入偏好存储那种坏法）。
                key: const Key('calendar_sidebar_toggle'),
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
                key: const Key('calendar_today_button'),
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

/// 紧凑档标题：日/周显示「月日」，列表显示「月日起」（窗口起点），月显示「年月」，年显示「年」（#178/#616）。
String _compactTitle(DateTime anchor, CalendarViewMode mode) {
  return switch (mode) {
    CalendarViewMode.day ||
    CalendarViewMode.week => '${anchor.month}月${anchor.day}日',
    // 列表档是「从锚点往后摊开的日程窗口」，标题给起点比给年月更贴合它显示的内容。
    CalendarViewMode.list => '${anchor.month}月${anchor.day}日起',
    CalendarViewMode.month => '${anchor.year}年${anchor.month}月',
    CalendarViewMode.year => '${anchor.year}年',
  };
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

/// 紧凑档视图切换（#178：日/周/月/年；#616 补上第 5 档列表）。
class _CompactViewModeMenu extends ConsumerWidget {
  const _CompactViewModeMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewModeProvider);
    const modes = [
      CalendarViewMode.day,
      CalendarViewMode.week,
      CalendarViewMode.month,
      CalendarViewMode.year,
      CalendarViewMode.list,
    ];
    return CupertinoMenuAnchor(
      menuChildren: [
        for (final m in modes)
          CupertinoMenuItem(
            key: Key('calendar_view_mode_${m.name}'),
            onPressed: () => ref.read(viewModeProvider.notifier).set(m),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m == mode) ...[
                  const Icon(CupertinoIcons.checkmark, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(CalendarToolbar._labels[m]!),
              ],
            ),
          ),
      ],
      builder: (context, controller, child) {
        return Semantics(
          label: '视图切换',
          button: true,
          child: CupertinoButton(
            key: const Key('calendar_view_mode_menu'),
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            onPressed: controller.open,
            child: const Icon(
              CupertinoIcons.calendar,
              size: 22,
              color: CupertinoColors.systemBlue,
            ),
          ),
        );
      },
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
      // #616：列表档如今是段里的第 5 格，段里恒有当前档 ⇒ 原先
      // `mode == list ? null : mode`（列表不在段内、只能画成「无选中」）一并摘掉。
      groupValue: mode,
      onValueChanged: (value) {
        if (value != null) {
          ref.read(viewModeProvider.notifier).set(value);
        }
      },
      children: {
        for (final m in modes) m: Text(CalendarToolbar._labels[m]!),
        // 第 5 档挂图标而不是「列表」二字：既有两条契约用例（TC-CAL-UI-001 判
        // 「不在任务列表页」、#399 判「列表视图的占位符没回来」）都拿
        // find.text('列表') 的**缺席**当判据；常驻工具栏里再放一份会同时作废它们。
        // 读屏侧用语义标签补回可说出的名字。
        CalendarViewMode.list: Semantics(
          key: const Key('calendar_view_mode_list'),
          label: '列表',
          child: const Icon(CupertinoIcons.list_bullet, size: 17),
        ),
      },
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

/// 紧凑档标题（#351 / #627）。
///
/// 两种让位方式按字号分档，各挡一种坏法：
/// · 常规字号用 `FittedBox(scaleDown)`——标题超出可用宽度时等比缩小，整串仍可读
/// （#627：375 宽下「2026年10月」比余量宽 0.18px，硬挤就抛 RenderFlex 溢出）。
/// · 大字号（辅助功能「更大的文字」）用省略号——此时缩放会把 17px 打到不可读，
///   截字比缩成蚂蚁好（#351：2.0 字号下这一行原本横向溢出 102px）。
/// 1.0 字号下 `scaleDown` 的缩放系数为 1，标题像素与改动前相同（golden 不漂）。
Widget _compactTitleText(BuildContext context, String text) {
  const style = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
  const threshold = 22.0; // 17 × ≈1.3：进入「需要让位」的字号区间
  final scaled = MediaQuery.textScalerOf(context).scale(style.fontSize!);
  if (scaled > threshold) {
    return Flexible(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
  return Flexible(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, style: style),
    ),
  );
}
