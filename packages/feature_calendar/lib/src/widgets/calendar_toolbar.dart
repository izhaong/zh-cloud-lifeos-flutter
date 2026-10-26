import 'package:flutter/material.dart';
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
  const CalendarToolbar({super.key, this.compact = false, this.onQuickCreate});

  /// 宽度 <600（iPhone 档）时用精简形态（契约 §8.5）。
  final bool compact;

  /// 「＋」打开快速事件输入框（F-12；由 scaffold 注入）。
  final VoidCallback? onQuickCreate;

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
              Text('${anchor.year}年${anchor.month}月',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                tooltip: '上一个月',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(ref, -1),
              ),
              IconButton(
                tooltip: '下一个月',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(ref, 1),
              ),
              const Spacer(),
              IconButton(
                tooltip: '搜索',
                icon: const Icon(Icons.search),
                onPressed: () =>
                    ref.read(searchActiveProvider.notifier).set(true),
              ),
              IconButton(
                tooltip: '新建日程',
                icon: const Icon(Icons.add),
                onPressed: onQuickCreate, // F-12 快速事件
              ),
            ],
          )
        : Row(
            children: [
              IconButton(
                tooltip: '新建日程',
                icon: const Icon(Icons.add),
                onPressed: onQuickCreate, // F-12 快速事件
              ),
              IconButton(
                tooltip: '日历列表',
                icon: const Icon(Icons.menu),
                onPressed: () => ref.read(sidebarVisibleProvider.notifier).toggle(),
              ),
              const SizedBox(width: 8),
              const Expanded(child: _ViewSegment()),
              IconButton(
                tooltip: '上一天/周/月/年',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(ref, -1),
              ),
              TextButton(
                onPressed: () => ref.read(anchorDateProvider.notifier).today(),
                child: const Text('今天'),
              ),
              IconButton(
                tooltip: '下一天/周/月/年',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(ref, 1),
              ),
              IconButton(
                tooltip: '收件箱',
                icon: const Icon(Icons.inbox_outlined),
                onPressed: () {}, // M4 收件箱
              ),
              IconButton(
                key: const Key('calendar_settings_button'),
                tooltip: '设置',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => showCalendarSettingsSheet(context),
              ),
              IconButton(
                tooltip: '搜索',
                icon: const Icon(Icons.search),
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
      CalendarViewMode.week =>
        anchor.add(Duration(days: direction * (mode == CalendarViewMode.week ? 7 : 1))),
      CalendarViewMode.month =>
        DateTime(anchor.year, anchor.month + direction, anchor.day),
      CalendarViewMode.year => DateTime(anchor.year + direction, anchor.month, anchor.day),
    };
    ref.read(anchorDateProvider.notifier).set(next);
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
    return SegmentedButton<CalendarViewMode>(
      segments: [
        for (final m in modes)
          ButtonSegment(value: m, label: Text(CalendarToolbar._labels[m]!)),
      ],
      selected: {if (mode != CalendarViewMode.list) mode},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          ref.read(viewModeProvider.notifier).set(selection.first);
        }
      },
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(searchQueryProvider));

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
            child: TextField(
              key: const Key('calendar_search_field'),
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '搜索日程（标题/地点/备注）',
                border: InputBorder.none,
              ),
              onChanged: (v) => ref.read(searchQueryProvider.notifier).set(v),
            ),
          ),
          IconButton(
            key: const Key('calendar_search_close'),
            tooltip: '关闭搜索',
            icon: const Icon(Icons.close),
            onPressed: () {
              _controller.clear();
              ref.read(searchQueryProvider.notifier).set('');
              ref.read(searchActiveProvider.notifier).set(false);
            },
          ),
        ],
      ),
    );
  }
}
