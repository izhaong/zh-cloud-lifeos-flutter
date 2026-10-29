import 'package:intl/intl.dart';

/// 区域 tag → 首个工作日（1=周一…7=周日）。
///
/// **纯函数**：输入 tag，输出 1..7。`null`/空/解析失败一律回落周一。
///
/// 为什么必须可注入：此前直接读 `PlatformDispatcher.instance.locale`，
/// 在 widget 测试里这个值不确定（同一份代码实测得到 6=周六），
/// 于是月视图网格起点随环境漂移——`search_shortcuts_test` 就是这么被压红的
/// （#468）。生产仍取系统区域，测试显式钉死。
int startWeekOnForLocale(String? localeTag) {
  if (localeTag == null || localeTag.trim().isEmpty) return DateTime.monday;
  try {
    // **intl 的 FIRSTDAYOFWEEK 是 0=周一…6=周日**（不是 0=周日！）。
    // 实测：en_US → 6（周日）、de_DE（已 initializeDateFormatting 时）→ 0（周一）。
    // 转成 `DateTime` 的 1..7 要 `+1`。第一版把它当 0=周日，导致 en_US 算成周六（6），
    // 月视图网格整体错位——#468 的直接原因。
    final first = DateFormat.yMd(localeTag).dateSymbols.FIRSTDAYOFWEEK;
    final day = first + 1;
    if (day >= 1 && day <= 7) return day;
    return DateTime.monday;
  } catch (_) {
    // intl 未 `initializeDateFormatting` 时，非 en_US 的 tag 会抛——
    // 那个场合回落到周一（确定性优先；生产侧组合根已调 initialize）。
    return DateTime.monday;
  }
}

/// 偏好值 → 生效的周起始：`0`=跟随系统/给定 tag；`1..7`=显式。
int effectiveStartWeekOn(int raw, {String? localeTag}) =>
    raw >= 1 && raw <= 7 ? raw : startWeekOnForLocale(localeTag);
