import 'design/calendar_tokens.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'calendar_view_callbacks.dart';
import 'logic/quick_event_draft.dart';
import 'views/day_view.dart';
import 'views/list_view.dart';
import 'views/month_view.dart';
import 'views/year_view.dart';
import 'widgets/calendar_sidebar.dart';
import 'widgets/calendar_shortcuts.dart';
import 'widgets/event_inspector_pane.dart';
import 'widgets/quick_event_dialog.dart';
import 'widgets/quick_reminder_dialog.dart';
import 'widgets/calendar_settings_sheet.dart';
import 'widgets/shortcut_dialogs.dart';
import 'widgets/subscription_dialog.dart';
import 'widgets/month_strip.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'widgets/calendar_toolbar.dart';

/// 日历三档骨架（契约 §5.4/§8.5）：
/// compact=月条+日列表/日时间轴切换；medium=侧栏+主视图；expanded=侧栏+主视图+Inspector。
///
/// F-03 骨架：工具栏 + 主视图槽位就位；侧栏（F-04）、Inspector（F-08）、
/// 日/周/月/年真实视图（F-05～F-07）按卡填充。
class CalendarScaffold extends ConsumerWidget {
  const CalendarScaffold({super.key, this.pinnedViewMode});

  /// 钉死视图档（测试/特殊宿主用；不传则跟随 `viewModeProvider`）。
  ///
  /// #628：这参数过去叫 `initialViewMode`，实现却是
  /// `pinnedViewMode ?? watch(viewModeProvider)`——传了值就永远等于那个值，
  /// provider 之后的变化被整段忽略，名字说的「初始」并不成立。
  /// 改名后名字与行为一致。要「起始档、之后仍可切换」的正路是先写
  /// `viewModeProvider`（`ref.read(viewModeProvider.notifier).set(...)`），
  /// 不是用它。
  final CalendarViewMode? pinnedViewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarViewMode mode =
        pinnedViewMode ?? ref.watch(viewModeProvider);
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

    // 保存后只清草稿：关页由 EventInspectorHost 用自己的路由 context 完成。
    // 这里再 pop 会在 expanded 第三栏（无路由可 pop）把壳分支根页 pop 掉，
    // 触发 go_router 断言白屏（#154）。
    void saveAndClose() {
      clearDraft();
    }

    // 草稿落位 + 三档呈现（F-08）。断点口径与内容区一致：由 LayoutBuilder
    // 传入内容宽（compact 全屏 / medium sheet / expanded 第三栏；#407 expanded 阈值 1000）。
    // F-10：occurrence 打开时带上该次原始开始（重复事件作用域）
    void openDraft(
      CalendarEvent draft,
      DateTime? occurrenceStart,
      double contentWidth,
    ) {
      ref.read(draftOccurrenceStartProvider.notifier).set(occurrenceStart);
      ref.read(draftEventProvider.notifier).setDraft(draft);
      if (contentWidth >= 1000) {
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
        EventInspectorHost.openFullScreen(
          context,
          draft,
          saveAndClose,
          occurrenceStart: occurrenceStart,
          onDismissed: routeDone,
        );
      } else {
        EventInspectorHost.openSheet(
          context,
          draft,
          saveAndClose,
          occurrenceStart: occurrenceStart,
          onDismissed: routeDone,
        );
      }
    }

    CalendarViewCallbacks viewCallbacksOf(double contentWidth) {
      return CalendarViewCallbacks(
        repo: repo,
        preference: preference,
        timeZone: ref.read(deviceTimeZoneProvider).value ?? 'UTC',
        reminderRepository: ref.read(calendarReminderRepositoryProvider),
        setDraft: (draft) => openDraft(draft, null, contentWidth),
        openOccurrence: (draft, occurrenceStart) =>
            openDraft(draft, occurrenceStart, contentWidth),
      );
    }

    // 内容区实测宽（LayoutBuilder 每帧回写）：openDraft 的断点判定必须与
    // build 尾部第三栏用同一把尺——真实壳层有左轨，MediaQuery 整窗宽比内容
    // 宽大，1000–1439 窗宽带会误判 expanded 导致草稿悬空（#197 审查 R1；
    // #407 按 Apple 把 expanded 阈值从 1200 降到 1000，判定仍只看实测内容宽）。
    var measuredContentWidth = 0.0;

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
      // #620（TC-CAL-UI-204 后半句「保存后回到日视图」）：锚点落到被创建的那一天。
      // 档位不动（compact 打开时本来就是日档，强改档会跟 #613 的方向段互相覆盖）；
      // 但锚点必须跟过去——在 10/29 上建一条 11/20 的日程，看完还停在 10/29 就等于没回去。
      // 尺子与 openQuickReminder 同一把（`startAt.toLocal()`）。
      final created = quick.startAt.toLocal();
      ref
          .read(anchorDateProvider.notifier)
          .set(DateTime(created.year, created.month, created.day));
      // #219：未写日期的全天事件按设备本地当天锚定（UTC 墙钟会漂到前一天）
      final draft = quickEventDraft(quick, timeZone: zone);
      openDraft(draft, null, measuredContentWidth);
    }

    // F-15：＋ → 新建提醒（快速输入复用 F-12；写入 ReminderRepository）
    Future<void> openQuickReminder() async {
      final reminderRepo = ref.read(calendarReminderRepositoryProvider);
      final lists =
          ref.read(reminderListsForCalendarProvider).value ??
          const <ReminderList>[];
      final targets = lists.where((l) => !l.isSmart).toList();
      if (reminderRepo == null || targets.isEmpty) {
        return;
      }
      final quick = await showQuickReminderDialog(
        context,
        lists: targets,
        timeZone: 'UTC',
      );
      if (quick == null || !context.mounted) {
        return;
      }
      final local = quick.event.startAt.toLocal();
      final dueAt = quick.event.allDay
          ? DateTime(local.year, local.month, local.day)
          : local;
      await reminderRepo.upsertItem(
        ReminderItem(
          id: newReminderId(),
          // #401：落点由用户在面板里指定，不再恒取首个列表
          listId: quick.listId,
          title: quick.event.title,
          dueAt: dueAt,
        ),
      );
    }

    final scaffold = CupertinoPageScaffold(
      backgroundColor: CalendarTokens.groupedBackground,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            measuredContentWidth = width;
            final compact = width < 600; // 契约 §8.5 iPhone 档
            final expanded = width >= 1000;
            // 契约 §8.5（#613）手机横屏段：高<宽 且 高 ≤ 450 且 宽 < 1000。
            // 三条各挡一种误伤——只横过来才生效；桌面窄长窗（900×500）不被当手机
            // （手机横屏后可用高最多是长边量级，iPhone 15 Pro Max 横屏 932×430）；
            // iPad 横屏（1024×768）仍走 expanded 三栏。方向只从 constraints 推，
            // 绝不按 Platform.is* 分叉。
            final height = constraints.maxHeight;
            final phoneLandscape =
                height < width && height <= 450 && width < 1000;
            if (phoneLandscape &&
                pinnedViewMode == null &&
                mode == CalendarViewMode.day) {
              // 「变为周视图」要落到档位本身，段控件才不会亮着「日」而画一整周。
              // 不在 build 里同步写 provider：帧末再写，避免这条通知插进正在
              // 拆装的子树（#632 刚在那边证过一次同族风险）。
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ref.read(viewModeProvider) == CalendarViewMode.day) {
                  ref.read(viewModeProvider.notifier).set(CalendarViewMode.week);
                }
              });
            }
            final viewCallbacks = viewCallbacksOf(width);
            Widget content = Column(
              children: [
                CalendarToolbar(
                  compact: compact,
                  onQuickCreate: openQuickEvent,
                  onQuickCreateReminder: openQuickReminder,
                ),
                const _Hairline(),
                // #612：契约 §589 的 iPhone「月条」此前没有任何挂载点（MiniMonth
                // 只挂在侧栏，而 compact 整条侧栏都不挂）。条只在 compact 出现，
                // medium/expanded 仍走侧栏那份月历，两处互斥不重复渲染。
                // 月档/年档不挂：那两档屏上已经是整月（12 个迷你月），条会重复同一功能
                // 并白吃掉 52 高；日/周/列表是逐日窗口，条才是它们的跳转面。
                if (compact && mode != CalendarViewMode.month &&
                    mode != CalendarViewMode.year) ...[
                  const MonthStrip(),
                  const _Hairline(),
                ],
                Expanded(
                  child: _MainView(
                    mode: mode,
                    compact: compact,
                    viewCallbacks: viewCallbacks,
                    eventsController: eventsController,
                  ),
                ),
              ],
            );
            if (!compact && !phoneLandscape && sidebarVisible) {
              // 契约 §8.5：medium 240（600–999）、expanded 280（≥1000；#407）。
              // 手机横屏段不挂：期望是「侧栏不挂」，横屏要给整周留出宽度（#613）。
              content = Row(
                children: [
                  CalendarSidebar(width: expanded ? 280 : 240),
                  const _VerticalHairline(),
                  Expanded(child: content),
                ],
              );
            }
            // F-08：expanded 档第三栏 Inspector（草稿存在时；#407 起内容宽 ≥1000）。
            // 断点跨档防重复编辑面：只保留一个活动 Inspector——
            // sheet/route 打开时由 _inspectorRouteActive 标记，第三栏不挂；
            // 反之第三栏挂载期间 draft 持有唯一编辑权（pane 变更不回写 provider，
            // 保存/关闭才清）。
            final draft = ref.watch(draftEventProvider);
            if (expanded && draft != null && !inspectorRouteActive) {
              content = Row(
                children: [
                  // #197：必须用 Expanded 包裹——content（侧栏+主视图 Row，
                  // 内含 Expanded）作为非 flex 子项会拿到无界宽度，内层
                  // Expanded 布局直接抛 RenderFlex 异常，整骨架渲染中断，
                  // 表现为「创建后什么都不出现」。
                  Expanded(child: content),
                  const _VerticalHairline(),
                  SizedBox(
                    width: 320,
                    child: EventInspectorPane(
                      initialEvent: draft,
                      occurrenceStart: ref.watch(draftOccurrenceStartProvider),
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

    // #400：下面 9 条此前只注册了 Action、没注入回调，按下去 `?.call()` 静默。
    // 每条都接到一条已存在的能力链上，不新造第二套语义。
    Future<void> refresh() async {
      await ref.read(calendarSyncTriggerProvider)?.call();
      if (!context.mounted) {
        return;
      }
      ref.invalidate(calendarsProvider);
      ref.invalidate(preferenceProvider);
    }

    /// 只有日程主记录可以编辑/移动/删除；提醒与节假日是投影。
    CalendarOccurrence? selectedEventOccurrence() {
      final sel = ref.read(selectedOccurrenceProvider);
      if (sel == null || sel.source != OccurrenceSource.event) {
        return null;
      }
      return sel;
    }

    // ⌘E（编辑所选）与 ⌥⌘I（Inspector）落同一个编辑面：本应用只有一个日程
    // 编辑面，Apple 的这两条键在此处语义重合。
    Future<void> openSelectedEditor() async {
      final sel = selectedEventOccurrence();
      if (sel == null) {
        return;
      }
      final draft = await repo.getEvent(sel.masterEventId);
      if (draft == null || !context.mounted) {
        return;
      }
      openDraft(draft, sel.isRecurring ? sel.start : null, measuredContentWidth);
    }

    Future<void> jumpToDate() async {
      final picked = await showJumpToDateDialog(
        context,
        initial: ref.read(anchorDateProvider),
      );
      if (picked == null || !context.mounted) {
        return;
      }
      ref.read(anchorDateProvider.notifier).set(picked);
    }

    Future<void> showSelectedInfo() async {
      final sel = ref.read(selectedOccurrenceProvider);
      if (sel == null || !context.mounted) {
        return;
      }
      await showOccurrenceInfoDialog(context, occurrence: sel);
    }

    Future<void> moveSelected(Duration delta) async {
      final sel = selectedEventOccurrence();
      if (sel == null) {
        return;
      }
      final base = await repo.getEvent(sel.masterEventId);
      if (base == null) {
        return;
      }
      await repo.upsertEvent(
        _shiftEventTimes(base, delta),
        scope: sel.isRecurring ? EditScope.thisOnly : EditScope.all,
        occurrenceStart: sel.isRecurring ? sel.start : null,
      );
    }

    Future<void> deleteSelected() async {
      final sel = selectedEventOccurrence();
      if (sel == null) {
        return;
      }
      await repo.deleteEvent(
        sel.masterEventId,
        scope: sel.isRecurring ? EditScope.thisOnly : EditScope.all,
        occurrenceStart: sel.isRecurring ? sel.start : null,
      );
      ref.read(selectedOccurrenceProvider.notifier).select(null);
    }

    return CalendarShortcutActions(
      onNextPeriod: () => shiftPeriod(1),
      onPrevPeriod: () => shiftPeriod(-1),
      onToday: () => ref.read(anchorDateProvider.notifier).today(),
      onJumpToDate: jumpToDate,
      onSetViewMode: (m) => ref.read(viewModeProvider.notifier).set(m),
      onRefresh: refresh,
      onNewEvent: openQuickEvent,
      onEditSelected: openSelectedEditor,
      onOpenInspectorWindow: openSelectedEditor,
      onFocusSearch: () => ref.read(searchActiveProvider.notifier).set(true),
      onShowInfo: showSelectedInfo,
      // 本仓没有独立分组实体（侧栏分组由 Calendar.groupName 派生），Apple 的
      // ⇧⌘N 即 File ▸ New Calendar…，故接到与侧栏同一条新建日历链上。
      onNewCalendarGroup: () => showAddCalendarDialog(context, ref),
      onNewSubscription: () =>
          showLocalSubscriptionDialog(context, repository: repo),
      onMoveSelection: moveSelected,
      onSettings: () => showCalendarSettingsSheet(context),
      onDeleteSelected: deleteSelected,
      onCloseEditing: clearDraft,
      // 空格切显隐已由侧栏本地 Actions 接住（#360），此处重复注入会切两次。
      child: scaffold,
    );
  }
}

/// ⌃⌥方向键：整段平移（起止同时偏移），其余字段原样回写。
/// `CalendarEvent` 无 copyWith，编辑语义按契约 §5.2 由 UI 全量构造。
CalendarEvent _shiftEventTimes(CalendarEvent e, Duration delta) =>
    CalendarEvent(
      id: e.id,
      remoteId: e.remoteId,
      calendarId: e.calendarId,
      uid: e.uid,
      title: e.title,
      location: e.location,
      url: e.url,
      attachmentUrl: e.attachmentUrl,
      notes: e.notes,
      startAt: e.startAt.add(delta),
      endAt: e.endAt.add(delta),
      allDay: e.allDay,
      timeZone: e.timeZone,
      isFloating: e.isFloating,
      rrule: e.rrule,
      exdates: e.exdates,
      parentEventId: e.parentEventId,
      originalStartAt: e.originalStartAt,
      status: e.status,
      availability: e.availability,
      travelMinutes: e.travelMinutes,
      isPrivate: e.isPrivate,
      alerts: e.alerts,
      invitees: e.invitees,
      sequence: e.sequence,
      revision: e.revision,
      deletedAt: e.deletedAt,
      updatedAt: e.updatedAt,
    );

class _MainView extends ConsumerWidget {
  const _MainView({
    required this.mode,
    required this.compact,
    required this.viewCallbacks,
    required this.eventsController,
  });

  final CalendarViewMode mode;

  /// #185：断点只在外壳取值；叶子视图按此开关决定是否挂宽档专属栏。
  final bool compact;
  final CalendarViewCallbacks viewCallbacks;
  final kalender.DefaultEventsController eventsController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // F-05：日/周真视图；月/年/列表随 F-06/F-07/F-13 替换
    final view = switch (mode) {
      CalendarViewMode.day => CalendarDayView(
        viewCallbacks: viewCallbacks,
        eventsController: eventsController,
        showReminderLane: !compact,
      ),
      CalendarViewMode.week => CalendarWeekView(
        viewCallbacks: viewCallbacks,
        eventsController: eventsController,
      ),
      CalendarViewMode.month => CalendarMonthView(
        viewCallbacks: viewCallbacks,
        eventsController: eventsController,
      ),
      CalendarViewMode.year => const CalendarYearView(),
      CalendarViewMode.list => const CalendarListView(),
    };
    // 裸键（Delete/Esc/Return）只在主视图内生效，避免吞掉表单文本输入。
    // #400：按键沿「焦点节点 → 祖先」冒泡，而 Shortcuts 的 onKey 挂在它自己
    // 那层 Focus 上——焦点必须落在 Shortcuts **之内**才轮得到它。此前焦点停在
    // scaffold 根，Delete 根本没进这条绑定，所以让主视图子树自己取焦点。
    return Shortcuts(
      shortcuts: calendarUnmodifiedShortcutBindings(),
      child: Focus(
        autofocus: true,
        child: view,
      ),
    );
  }
}

/// Apple 式 0.5px 发丝分隔线。
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    // #295：同侧栏背景——不 resolve 就会在暗色档画出亮色发丝线。
    return Container(
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );
  }
}

/// 竖向发丝分隔线。
class _VerticalHairline extends StatelessWidget {
  const _VerticalHairline();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 0.5,
      child: ColoredBox(
        color: CupertinoColors.separator.resolveFrom(context),
      ),
    );
  }
}
