import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/calendar_tokens.dart';
import '../providers.dart';
import 'mini_month.dart';

/// iPhone 档月条（契约 §589；#612）：锚点当月逐日横滑，点某日改 `anchorDateProvider`。
///
/// 与侧栏 `MiniMonth` 的分工是互斥的：条只在 compact 挂，整月月历只在
/// medium/expanded 的侧栏挂 ⇒ 同一份月历不会渲染两遍（对照用例钉住这条）。
/// #630 补上「下拉展开整月」（TC-CAL-UI-202）：展开态直接复用 `MiniMonth`，
/// 本组件不新造第二套月历，且只在 compact 出现（布局仍只认 `WindowSizeClass`）。
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

  /// #630（TC-CAL-UI-202）：纵向拖过这个位移才展开。
  ///
  /// 比 `kTouchSlop`（18，手势被判定为「拖」的门槛）高一档 ⇒ 顺手轻碰不展开；
  /// 又远小于整屏高 ⇒ 不必真的「拉一屏」。
  static const double _expandThreshold = 24;

  final ScrollController _controller = ScrollController();

  /// 已对齐过的月份（year*100+month）。同月内换日不抢用户正在看的位置。
  int? _alignedMonth;

  /// 展开态（契约 §589「月条（可下拉展开整月）」）。默认收起——收起态就是
  /// `test/goldens/iphone_375_*.png` 画的那一形态，改默认值会让 golden 集体漂。
  bool _expanded = false;

  /// 本次纵向拖拽累计位移；松手/取消即清零，避免跨次拖拽相加造成误展开。
  double _dragDy = 0;

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          // 只挂纵向回调：横向由 SingleChildScrollView 的识别器要走去横滑选日，
          // 两者不在同一个主方向上抢角力（验收 3 的断言盯的就是这件事）。
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          onVerticalDragCancel: _resetDragDy,
          child: Container(
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
          ),
        ),
        if (_expanded)
          // 展开的是**同一份**迷你月历（期望 2：不新造第二套）；点中某日由
          // MiniMonth.onDayPicked 收起面板并落锚点（契约 §589 后半句）。
          Container(
            key: const Key('calendar_month_strip_expanded'),
            color: CalendarTokens.surface.resolveFrom(context),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: MiniMonth(
              compact: true,
              onDayPicked: () => setState(() => _expanded = false),
            ),
          ),
      ],
    );
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _dragDy += details.delta.dy;
    if (!_expanded && _dragDy >= _expandThreshold) {
      setState(() => _expanded = true);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) => _resetDragDy();

  void _resetDragDy() => _dragDy = 0;

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
