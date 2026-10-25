import 'package:flutter/material.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'providers.dart';
import 'calendar_view_callbacks.dart';
import 'views/day_view.dart';
import 'views/month_view.dart';
import 'views/year_view.dart';
import 'widgets/calendar_sidebar.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'widgets/calendar_toolbar.dart';

/// 日历三档骨架（契约 §5.4/§8.5）：
/// compact=月条+日列表/日时间轴切换；medium=侧栏+主视图；expanded=侧栏+主视图+Inspector。
///
/// F-03 骨架：工具栏 + 主视图槽位就位；侧栏（F-04）、Inspector（F-08）、
/// 日/周/月/年真实视图（F-05～F-07）按卡填充。
class CalendarScaffold extends ConsumerWidget {
  const CalendarScaffold({super.key, this.initialViewMode});

  /// 初始视图档（测试/路由用；默认 day）。
  final CalendarViewMode? initialViewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarViewMode mode =
        initialViewMode ?? ref.watch(viewModeProvider);
    final sidebarVisible = ref.watch(sidebarVisibleProvider);
    final eventsController = ref.watch(kalenderEventsControllerProvider);
    final viewCallbacks = CalendarViewCallbacks(
      repo: ref.read(calendarRepositoryProvider),
      preference:
          ref.watch(preferenceProvider).value ?? CalendarPreference.defaults,
      setDraft: (draft) =>
          ref.read(draftEventProvider.notifier).setDraft(draft),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = width < 600; // 契约 §8.5 iPhone 档
            final expanded = width >= 1200;
            Widget content = Column(
              children: [
                CalendarToolbar(compact: compact),
                const Divider(height: 1),
                Expanded(child: _MainView(
                    mode: mode, viewCallbacks: viewCallbacks,
                    eventsController: eventsController)),
              ],
            );
            if (!compact && sidebarVisible) {
              // 契约 §8.5：medium 240（600–1199）、expanded 280（≥1200）
              content = Row(
                children: [
                  CalendarSidebar(width: expanded ? 280 : 240),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              );
            }
            return content;
          },
        ),
      ),
    );
  }
}

class _MainView extends ConsumerWidget {
  const _MainView({required this.mode, required this.viewCallbacks, required this.eventsController});

  final CalendarViewMode mode;
  final CalendarViewCallbacks viewCallbacks;
  final kalender.DefaultEventsController eventsController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // F-05：日/周真视图；月/年/列表随 F-06/F-07/F-13 替换
    return switch (mode) {
      CalendarViewMode.day => CalendarDayView(viewCallbacks: viewCallbacks, eventsController: eventsController),
      CalendarViewMode.week => CalendarWeekView(viewCallbacks: viewCallbacks, eventsController: eventsController),
      CalendarViewMode.month => CalendarMonthView(
          viewCallbacks: viewCallbacks, eventsController: eventsController),
      CalendarViewMode.year => const CalendarYearView(),
      CalendarViewMode.list => const Center(child: Text('列表')),
    };
  }
}
