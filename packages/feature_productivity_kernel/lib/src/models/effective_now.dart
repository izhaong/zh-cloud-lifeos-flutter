// 「有效当下」（#448）：手动设定时区后，所有「今天/逾期」判定都要用同一个 now。
//
// 为什么需要它：`smart.today` 过滤、逾期样式、日期分组、徽标计数全都依赖
// 「现在是不是这一天」。若各处各取 `DateTime.now()`，用户设了手动时区后会出现
// 「侧栏说今天有 3 条、列表里只有 2 条」这类自相矛盾。
//
// 所以只保留**一个**入口：把系统时刻 + 偏好时区 → 有效墙钟时刻。
import 'package:timezone/timezone.dart' as tz;

/// 把系统时刻换算到 [ianaId] 时区的墙钟时间。
///
/// - [ianaId] 为 null/空 → 跟随系统（原样返回本地时间）；
/// - [ianaId] 不认识 → 也回落系统时间（**不抛**：一个坏设置不该让整个任务页崩）；
/// - 返回值是**该时区的墙钟时刻**（`DateTime` 仍是本地构造，但年月日时分已经是
///   目标时区的值）——因为全仓的「今天」判定都在比较年月日，不涉及时区换算。
DateTime effectiveNow(DateTime systemNow, String? ianaId) {
  if (ianaId == null || ianaId.isEmpty) return systemNow;
  try {
    final location = tz.getLocation(ianaId);
    final instant = tz.TZDateTime.from(systemNow.toUtc(), location);
    return DateTime(
      instant.year,
      instant.month,
      instant.day,
      instant.hour,
      instant.minute,
      instant.second,
    );
  } catch (_) {
    return systemNow;
  }
}
