import 'package:flutter/material.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'providers.dart';
import 'calendar_view_callbacks.dart';
import 'views/day_view.dart';
import 'views/month_view.dart';
import 'views/year_view.dart';
import 'widgets/calendar_sidebar.dart';
import 'widgets/calendar_shortcuts.dart';
import 'widgets/event_inspector_pane.dart';
import 'widgets/quick_event_dialog.dart';
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
    final inspectorRouteActive = ref.watch(inspectorRouteActiveProvider);
    final repo = ref.read(calendarRepositoryProvider);
    final preference =
        ref.watch(preferenceProvider).value ?? CalendarPreference.defaults;
    // 草稿清理（幂等）：route 关闭后 .then 兜底再清一次即可，绝不二次 pop。
    void clearDraft() {
      ref.read(draftEventProvider.notifier).clear();
      ref.read(draftOccurrenceStartProvider.notifier).set(null);
    }
    void saveAndClose() {
      clearDraft();
      Navigator.of(context).pop(); // 唯一 pop：保存路径
    }
    // 草稿落位 + 三档呈现（F-08）。断点口径与内容区一致：由 LayoutBuilder
    // 传入内容宽（compact 全屏 / medium sheet / expanded 第三栏）。
    // F-10：occurrence 打开时带上该次原始开始（重复事件作用域）
    void openDraft(
        CalendarEvent draft, DateTime? occurrenceStart, double contentWidth) {
      ref.read(draftOccurrenceStartProvider.notifier).set(occurrenceStart);
      ref.read(draftEventProvider.notifier).setDraft(draft);
      if (contentWidth >= 1200) {
        return; // 第三栏由 build 尾部呈现
      }
      // 已有 sheet/全屏在途：不叠第二层编辑面
      if (ref.read(inspectorRouteActiveProvider)) {
        return;
      }
      // 打开 sheet/全屏即标记路由编辑面在途（防宽度跨档双开）
      ref.read(inspectorRouteActiveProvider.notifier).set(true);
      void routeDone() {
        ref.read(inspectorRouteActiveProvider.notifier).set(false);
        clearDraft();
      }
      if (contentWidth < 600) {
        EventInspectorHost.openFullScreen(context, draft, saveAndClose,
            occurrenceStart: occurrenceStart, onDismissed: routeDone);
      } else {
        EventInspectorHost.openSheet(context, draft, saveAndClose,
            occurrenceStart: occurrenceStart, onDismissed: routeDone);
      }
    }

    CalendarViewCallbacks viewCallbacksOf(double contentWidth) {
      return CalendarViewCallbacks(
        repo: repo,
        preference: preference,
        setDraft: (draft) => openDraft(draft, null, contentWidth),
        openOccurrence: (draft, occurrenceStart) =>
            openDraft(draft, occurrenceStart, contentWidth),
      );
    }

    // F-12：⌘N 与工具栏「＋」打开同一个快速事件输入框
    Future<void> openQuickEvent() async {
      final zone = ref.read(deviceTimeZoneProvider).value ?? 'UTC';
      final quick = await showQuickEventDialog(
        context,
        defaultDurationMinutes: preference.defaultDurationMinutes,
        timeZone: zone,
      );
      if (quick == null || !context.mounted) {
        return;
      }
      final draft = CalendarEvent(
        id: kDraftEventId,
        calendarId: '',
        uid: '',
        title: quick.title,
        startAt: quick.startAt,
        endAt: quick.endAt,
        allDay: quick.allDay,
        timeZone: zone,
        updatedAt: DateTime.now().toUtc(),
      );
      openDraft(draft, null, MediaQuery.sizeOf(context).width);
    }

    final scaffold = Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = width < 600; // 契约 §8.5 iPhone 档
            final expanded = width >= 1200;
            final viewCallbacks = viewCallbacksOf(width);
            Widget content = Column(
              children: [
                CalendarToolbar(
                    compact: compact, onQuickCreate: openQuickEvent),
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
            // F-08：expanded 档第三栏 Inspector（草稿存在时）。
            // 断点跨档防重复编辑面：只保留一个活动 Inspector——
            // sheet/route 打开时由 _inspectorRouteActive 标记，第三栏不挂；
            // 反之第三栏挂载期间 draft 持有唯一编辑权（pane 变更不回写 provider，
            // 保存/关闭才清）。
            final draft = ref.watch(draftEventProvider);
            if (expanded && draft != null && !inspectorRouteActive) {
              content = Row(
                children: [
                  content,
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 320,
                    child: EventInspectorPane(
                      initialEvent: draft,
                      occurrenceStart:
                          ref.watch(draftOccurrenceStartProvider),
                      // 编辑回写 draftEventProvider：断点降档卸栏后未保存修改不丢
                      onDraftChanged: (next) =>
                          ref.read(draftEventProvider.notifier).setDraft(next),
                      onSaved: () =>
                          ref.read(draftEventProvider.notifier).clear(),
                      onClose: () =>
                          ref.read(draftEventProvider.notifier).clear(),
                    ),
                  ),
                ],
              );
            }
            return content;
          },
        ),
      ),
    );

    // F-13：快捷键表（⌘N/⌘F/⌘1-4/⌘T/⌘←→ 等）+ ⌘N 快速事件
    void shiftPeriod(int direction) {
      final anchor = ref.read(anchorDateProvider);
      final mode = ref.read(viewModeProvider);
      final next = switch (mode) {
        CalendarViewMode.day ||
        CalendarViewMode.list ||
        CalendarViewMode.week =>
          anchor.add(Duration(
              days: direction * (mode == CalendarViewMode.week ? 7 : 1))),
        CalendarViewMode.month =>
          DateTime(anchor.year, anchor.month + direction, anchor.day),
        CalendarViewMode.year =>
          DateTime(anchor.year + direction, anchor.month, anchor.day),
      };
      ref.read(anchorDateProvider.notifier).set(next);
    }

    return CalendarShortcutActions(
      onNextPeriod: () => shiftPeriod(1),
      onPrevPeriod: () => shiftPeriod(-1),
      onToday: () => ref.read(anchorDateProvider.notifier).today(),
      onSetViewMode: (m) => ref.read(viewModeProvider.notifier).set(m),
      onNewEvent: openQuickEvent,
      onFocusSearch: () => ref.read(searchActiveProvider.notifier).set(true),
      onCloseEditing: clearDraft,
      child: Focus(autofocus: true, child: scaffold),
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
    final view = switch (mode) {
      CalendarViewMode.day => CalendarDayView(viewCallbacks: viewCallbacks, eventsController: eventsController),
      CalendarViewMode.week => CalendarWeekView(viewCallbacks: viewCallbacks, eventsController: eventsController),
      CalendarViewMode.month => CalendarMonthView(
          viewCallbacks: viewCallbacks, eventsController: eventsController),
      CalendarViewMode.year => const CalendarYearView(),
      CalendarViewMode.list => const Center(child: Text('列表')),
    };
    // 裸键（Delete/Esc/Return）只在主视图内生效，避免吞掉表单文本输入
    return Shortcuts(
      shortcuts: calendarUnmodifiedShortcutBindings(),
      child: view,
    );
  }
}
