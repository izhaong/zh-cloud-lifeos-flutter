import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// 日历工具栏（契约 §5.4/§8.5）。
///
/// compact（<600，iPhone）：‹年月标题› ‹ › 搜索 ＋；
/// medium/expanded：＋ | 日历列表切换 | 日/周/月/年 分段 | ‹ 今天 › | 收件箱 | 搜索。
///
/// F-03 骨架：结构与 Key 就位（`calendar_toolbar`）；＋→F-12、列表切换→F-04、
/// 收件箱→M4、搜索→F-13 的行为随后续卡接入。
class CalendarToolbar extends ConsumerWidget {
  const CalendarToolbar({super.key, this.compact = false});

  /// 宽度 <600（iPhone 档）时用精简形态（契约 §8.5）。
  final bool compact;

  static const _labels = {
    CalendarViewMode.day: '日',
    CalendarViewMode.week: '周',
    CalendarViewMode.month: '月',
    CalendarViewMode.year: '年',
    CalendarViewMode.list: '列表',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onPressed: () {}, // F-13 搜索
              ),
              IconButton(
                tooltip: '新建日程',
                icon: const Icon(Icons.add),
                onPressed: () {}, // F-12 快速事件
              ),
            ],
          )
        : Row(
            children: [
              IconButton(
                tooltip: '新建日程',
                icon: const Icon(Icons.add),
                onPressed: () {}, // F-12 快速事件
              ),
              IconButton(
                tooltip: '日历列表',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () {}, // F-04 侧栏切换
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
                tooltip: '搜索',
                icon: const Icon(Icons.search),
                onPressed: () {}, // F-13 搜索
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
