import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../design/calendar_tokens.dart';
import '../logic/week_start.dart';
import '../providers.dart';

/// 迷你月历（契约 §5.4；F-04）。
///
/// medium/expanded 侧栏与 iPhone 月条共用；点日期改 anchorDateProvider；
/// 周起始按偏好 startWeekOn（0=跟随系统区域；#383）。table_calendar 为第三方 Material
/// 内核，按边界门禁以显式 Material 岛包裹（#130）。
class MiniMonth extends ConsumerWidget {
  const MiniMonth({super.key, this.compact = false});

  /// 紧凑模式：侧栏专用（行高压到 28、周标题 20），6 行 + 头部仍能塞进 ~260 高。
  /// 月/年视图里的用法保持默认尺寸。
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchor = ref.watch(anchorDateProvider);
    final preference = ref.watch(preferenceProvider).value;
    final weekStart = effectiveStartWeekOn(preference?.startWeekOn ?? 0);
    return LifeMaterialIsland(
      // #383：TableCalendar 内部是 Column，放大字号（2.0）或侧栏变矮时会
      // 「RenderFlex overflowed」；迷你月历本质是个紧凑小部件，等比缩小比裁剪好。
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 220,
          child: TableCalendar(
        firstDay: DateTime(anchor.year - 2, anchor.month, 1),
        lastDay: DateTime(anchor.year + 2, anchor.month, 1),
        focusedDay: anchor,
        // #553：不传 currentDay 时 TableCalendar 退回库内的裸 DateTime.now()
        // （其源码 line 63 / line 284），于是「今天」圈跟着真实日期跑：
        // 挂钟注入（#331）管不到它，golden 每过一天就自己飘一点。
        currentDay: ref.watch(clockProvider)(),
        startingDayOfWeek: weekStart == 7
            ? StartingDayOfWeek.sunday
            : StartingDayOfWeek.monday,
        selectedDayPredicate: (day) =>
            day.year == anchor.year &&
            day.month == anchor.month &&
            day.day == anchor.day,
        onDaySelected: (selected, focused) {
          ref
              .read(anchorDateProvider.notifier)
              .set(DateTime(selected.year, selected.month, selected.day));
        },
        onPageChanged: (focused) {
          ref
              .read(anchorDateProvider.notifier)
              .set(DateTime(focused.year, focused.month, focused.day));
        },
        // #383：TableCalendar 的周标题默认走 intl（未初始化时给英文 Tue/Wed…），
        // 本仓不做 intl 初始化，直接给中文标签，避免侧栏冒出英文缩写。
        calendarBuilders: CalendarBuilders(
          dowBuilder: (context, day) {
            const labels = ['一', '二', '三', '四', '五', '六', '日'];
            final index = day.weekday - (weekStart == 7 ? 6 : 1);
            final label = labels[(index % 7 + 7) % 7];
            return Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  color: CalendarTokens.labelSecondary.resolveFrom(context),
                ),
              ),
            );
          },
        ),
        rowHeight: compact ? 28 : 52,
        daysOfWeekHeight: compact ? 20 : 24,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          headerPadding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
        ),
        calendarStyle: const CalendarStyle(outsideDaysVisible: false),
        availableGestures: AvailableGestures.horizontalSwipe,
          ),
        ),
      ),
    );
  }
}
