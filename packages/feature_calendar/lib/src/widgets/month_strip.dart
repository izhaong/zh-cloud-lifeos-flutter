import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/calendar_tokens.dart';
import '../providers.dart';

/// iPhone 档月条（契约 §589；#612）：锚点当月逐日横滑，点某日改 `anchorDateProvider`。
///
/// 与侧栏 `MiniMonth` 的分工是互斥的：条只在 compact 挂，整月月历只在
/// medium/expanded 的侧栏挂 ⇒ 同一份月历不会渲染两遍（对照用例钉住这条）。
/// 「下拉展开整月」属 TC-CAL-UI-202，展开态直接复用 `MiniMonth`，本组件不新造第二套月历。
class MonthStrip extends ConsumerStatefulWidget {
  const MonthStrip({super.key});

  /// 单格宽：375 档一屏约 8.5 格，够读「周几 + 日号」，又不至于吃掉日视图的高度。
  static const double chipWidth = 44;

  static const double height = 52;

  @override
  ConsumerState<MonthStrip> createState() => _MonthStripState();
}

class _MonthStripState extends ConsumerState<MonthStrip> {
  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  final ScrollController _controller = ScrollController();

  /// 已对齐过的月份（year*100+month）。同月内换日不抢用户正在看的位置。
  int? _alignedMonth;

  @override
  void initState() {
    super.initState();
    // 首帧之后才有 ScrollController 客户端，此时才能把选中日滚到视口中部。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _alignTo(ref.read(anchorDateProvider));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _alignTo(DateTime anchor) {
    final monthKey = anchor.year * 100 + anchor.month;
    if (_alignedMonth == monthKey || !_controller.hasClients) {
      return;
    }
    _alignedMonth = monthKey;
    final target = (anchor.day - 1) * MonthStrip.chipWidth -
        _controller.position.viewportDimension / 2 +
        MonthStrip.chipWidth / 2;
    _controller.jumpTo(
      target.clamp(0.0, _controller.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anchor = ref.watch(anchorDateProvider);
    ref.listen(anchorDateProvider, (previous, next) => _alignTo(next));
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    return Container(
      key: const Key('calendar_month_strip'),
      height: MonthStrip.height,
      color: CalendarTokens.surface.resolveFrom(context),
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (var day = 1; day <= daysInMonth; day++) _chip(anchor, day),
          ],
        ),
      ),
    );
  }

  Widget _chip(DateTime anchor, int day) {
    final date = DateTime(anchor.year, anchor.month, day);
    final weekday = _weekdayLabels[date.weekday - 1];
    final selected = anchor.day == day;
    return SizedBox(
      width: MonthStrip.chipWidth,
      // 语义节点自己带 Key：断言直接读这个节点的 label 与 selected，
      // 不靠颜色（选中态此前在这类控件里只有颜色/字重，读屏读不出选到哪天）。
      child: Semantics(
        key: ValueKey('calendar_month_strip_day_$day'),
        button: true,
        selected: selected,
        label: '${anchor.month}月$day日 周$weekday',
        child: CupertinoButton(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          onPressed: () => ref
              .read(anchorDateProvider.notifier)
              .set(DateTime(anchor.year, anchor.month, day)),
          child: Container(
            decoration: selected
                ? BoxDecoration(
                    color: CalendarTokens.chipBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: FittedBox(
              // #383 口径（与 MiniMonth 同）：放大字号时等比缩小，比裁剪或溢出好。
              // 月条整条高度恒定（52），字号 2.0 靠缩放放下，不去挤主视图的高度。
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    weekday,
                    style: TextStyle(
                      fontSize: 11,
                      color: CalendarTokens.labelSecondary.resolveFrom(context),
                    ),
                  ),
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? CalendarTokens.systemBlue
                          : CalendarTokens.labelStrong.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
