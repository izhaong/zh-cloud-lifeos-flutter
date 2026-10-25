import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'providers.dart';
import 'widgets/calendar_toolbar.dart';

/// 日历三档骨架（契约 §5.4/§8.5）：
/// compact=月条+日列表/日时间轴切换；medium=侧栏+主视图；expanded=侧栏+主视图+Inspector。
///
/// F-03 骨架：工具栏 + 主视图槽位就位；侧栏（F-04）、Inspector（F-08）、
/// 日/周/月/年真实视图（F-05～F-07）按卡填充。
class CalendarScaffold extends ConsumerWidget {
  const CalendarScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewModeProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600; // 契约 §8.5 iPhone 档
            return Column(
              children: [
                CalendarToolbar(compact: compact),
                const Divider(height: 1),
                Expanded(child: _MainView(mode: mode)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MainView extends ConsumerWidget {
  const _MainView({required this.mode});

  final CalendarViewMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // F-05～F-07 逐档替换；骨架档给出空态占位（不自创信息架构）
    return Center(
      child: Text(
        switch (mode) {
          CalendarViewMode.day => '日',
          CalendarViewMode.week => '周',
          CalendarViewMode.month => '月',
          CalendarViewMode.year => '年',
          CalendarViewMode.list => '列表',
        },
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
