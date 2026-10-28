import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../design/calendar_tokens.dart';
import '../providers.dart';

/// 年视图（契约 §5.4；F-07）。
///
/// 自绘 12 个迷你月（4×3 网格）：今天红圈；有事件的日期下画小圆点
/// （最多 3 个颜色，去重自日历色）；点某月切到月视图并设 anchorDate。
/// 不引入新依赖（纯 GridView/Column 自绘）。
/// Key：`calendar_year_view`。
class CalendarYearView extends ConsumerWidget {
  const CalendarYearView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchor = ref.watch(anchorDateProvider);
    final year = anchor.year;
    final today = DateTime.now();
    // 全年 occurrence 一次取齐（12 个月窗）；点聚合按「日期 → 去重颜色」。
    final occurrences =
        ref
            .watch(
              occurrencesProvider((
                DateTime(year, 1, 1),
                DateTime(year + 1, 1, 1),
              )),
            )
            .value ??
        const <CalendarOccurrence>[];
    final dotsByDate = <DateTime, Set<int>>{};
    for (final o in occurrences) {
      if (o.source != OccurrenceSource.event) {
        continue;
      }
      // start 为 UTC：按本地日切分；跨日 occurrence 逐日画点（含首尾）
      final localStart = o.start.toLocal();
      final localEnd = o.end.toLocal();
      var day = DateTime(localStart.year, localStart.month, localStart.day);
      final lastDay = DateTime(localEnd.year, localEnd.month, localEnd.day);
      // 排他 end 落在整点零分即不含该日；否则含尾日
      final endInclusive = localEnd.hour != 0 || localEnd.minute != 0;
      final last = endInclusive
          ? lastDay
          : lastDay.subtract(const Duration(days: 1));
      while (!day.isAfter(last)) {
        dotsByDate.putIfAbsent(day, () => <int>{}).add(o.colorArgb);
        day = day.add(const Duration(days: 1));
      }
    }

    return KeyedSubtree(
      key: const Key('calendar_year_view'),
      child: GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        padding: const EdgeInsets.all(12),
        childAspectRatio: 0.9,
        children: [
          for (var month = 1; month <= 12; month++)
            _MiniMonthCard(
              key: Key('year_month_$month'),
              year: year,
              month: month,
              isCurrentMonth: anchor.month == month,
              today: today,
              dotsByDate: dotsByDate,
              onMonthTap: () {
                ref
                    .read(anchorDateProvider.notifier)
                    .set(DateTime(year, month, 1));
                ref.read(viewModeProvider.notifier).set(CalendarViewMode.month);
              },
            ),
        ],
      ),
    );
  }
}

/// 单个迷你月卡：月名 + 周行 × 日格；今天红圈；事件日最多 3 个色点。
class _MiniMonthCard extends StatelessWidget {
  const _MiniMonthCard({
    super.key,
    required this.year,
    required this.month,
    required this.isCurrentMonth,
    required this.today,
    required this.dotsByDate,
    required this.onMonthTap,
  });

  final int year;
  final int month;
  final bool isCurrentMonth;
  final DateTime today;
  final Map<DateTime, Set<int>> dotsByDate;
  final VoidCallback onMonthTap;

  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    // 周一起始：周一=0 … 周日=6
    final leadBlanks = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final isTodayMonth = today.year == year && today.month == month;

    return GestureDetector(
      key: Key('year_month_${month}_tap'),
      behavior: HitTestBehavior.opaque,
      onTap: onMonthTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isCurrentMonth
              ? CalendarTokens.systemBlue.withAlpha(20)
              : CupertinoColors.white,
          borderRadius: BorderRadius.circular(8),
          border: isCurrentMonth
              ? Border.all(color: CalendarTokens.systemBlue)
              : Border.all(color: CalendarTokens.hairline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
              '$month 月',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isCurrentMonth
                    ? CalendarTokens.systemBlue
                    : CalendarTokens.labelStrong,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final w in _weekLabels)
                  Text(
                    w,
                    style: const TextStyle(
                      fontSize: 8,
                      color: CalendarTokens.labelSecondary,
                    ),
                  ),
              ],
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 7,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < leadBlanks; i++) const SizedBox(),
                  for (var day = 1; day <= daysInMonth; day++)
                    _dayCell(day, isTodayMonth && today.day == day),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(int day, bool isToday) {
    final date = DateTime(year, month, day);
    final dots = dotsByDate[date]?.take(3).toList() ?? const <int>[];
    // 小格子（约 16px）内 Column 会溢出：用 FittedBox 缩放内容并禁点行膨胀
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: isToday ? Key('year_today_${month}_$day') : null,
            decoration: isToday
                ? const BoxDecoration(
                    shape: BoxShape.circle,
                    color: CalendarTokens.systemRed,
                  )
                : null,
            padding: isToday ? const EdgeInsets.all(1) : null,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 8,
                height: 1,
                color: isToday
                    ? CupertinoColors.white
                     : CalendarTokens.labelStrong,
              ),
            ),
          ),
          if (dots.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in dots)
                  Container(
                    key: Key(
                      'year_dot_${month}_${day}_${color.toRadixString(16)}',
                    ),
                    width: 2,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(color),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
