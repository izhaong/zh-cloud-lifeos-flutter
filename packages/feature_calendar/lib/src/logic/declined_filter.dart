import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// #645 / 矩阵 I8：「显示已拒绝日程」的过滤判据（纯函数，便于逐条钉）。
///
/// 语义对齐 Apple：**只看我自己的应答**——受邀者里没有我、或我压根没表过态，
/// 这条事件照常显示；别人的 declined 与我的视图无关。
/// `memberId` 为空（未登录/离线/会话还没读到）时也**不过滤**：判不出是不是我拒的，
/// 就不能静默把日程藏掉（与「日历列表还没加载时不按可见性过滤」同一口径）。
bool shouldHideDeclined({
  required bool showDeclinedEvents,
  required String? memberId,
}) =>
    !showDeclinedEvents && memberId != null && memberId.isNotEmpty;

/// 我自己在这条事件上是否答了「拒绝」。
bool declinedByMe(CalendarEvent e, String? memberId) => memberId != null &&
    e.invitees.any(
      (i) => i.memberUserId == memberId && i.partstat == PartStat.declined,
    );

List<CalendarEvent> filterDeclined(
  List<CalendarEvent> events, {
  required bool showDeclinedEvents,
  required String? memberId,
}) {
  if (!shouldHideDeclined(
    showDeclinedEvents: showDeclinedEvents,
    memberId: memberId,
  )) {
    return events;
  }
  return events
      .where((e) => !declinedByMe(e, memberId))
      .toList(growable: false);
}
