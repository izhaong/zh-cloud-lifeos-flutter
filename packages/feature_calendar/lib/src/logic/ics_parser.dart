// 订阅日历的 ICS 解析（#403）。
//
// 此前「添加订阅」只把 URL 存进 `Calendar.sourceUrl`，**不发任何请求**——订阅后
// 永远没有事件（侧栏注释自己写着「F-16：订阅占位」）。
//
// 这里只做**纯解析**：输入一段 ICS 文本，输出事件草稿。抓取由 `SubscriptionFetcher`
// 端口负责（组合根注入；开源包默认不联网，测试用假 HTTP）。
//
// 覆盖范围（够订阅日历用，不做 ical4j 全量）：
// - 行折叠（RFC 5545 §3.1：以空格/Tab 续行）；
// - `VEVENT` 的 `UID` / `SUMMARY` / `DTSTART` / `DTEND` / `DESCRIPTION` / `LOCATION`；
// - `DTSTART;VALUE=DATE:20261029`（全天）与 `DTSTART:20261029T090000Z`（定时，UTC）；
// - 文本反斜杠转义（`\\n` `\\,` `\\;` `\\\\`）。
// 明确不覆盖：RRULE 展开、VTIMEZONE、VALARM、EXDATE——交给「不支持就跳过」策略，
// 避免半吊子实现给出错误时间。
import '../models/ics_event.dart';

/// 解析结果（事件 + 被跳过的条数，便于 UI 如实说明）。
class IcsParseResult {
  const IcsParseResult({required this.events, required this.skipped});

  final List<IcsEvent> events;

  /// 解析不了（缺 DTSTART / 带 RRULE 等）而被跳过的 VEVENT 数。
  final int skipped;
}

/// 解析 ICS 文本。
IcsParseResult parseIcs(String raw) {
  // 1) 先拆行折叠：续行以空格或 Tab 开头，接在上一行**去掉换行**之后。
  final unfolded = <String>[];
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    if (line.startsWith(' ') || line.startsWith('\t')) {
      if (unfolded.isNotEmpty) {
        unfolded[unfolded.length - 1] += line.substring(1);
      }
      continue;
    }
    unfolded.add(line);
  }

  final events = <IcsEvent>[];
  var skipped = 0;
  Map<String, String>? current;

  void flush() {
    final props = current;
    current = null;
    if (props == null) return;
    final event = _toEvent(props);
    if (event == null) {
      skipped++;
      return;
    }
    events.add(event);
  }

  for (final line in unfolded) {
    final upper = line.toUpperCase();
    if (upper == 'BEGIN:VEVENT') {
      current = <String, String>{};
      continue;
    }
    if (upper == 'END:VEVENT') {
      flush();
      continue;
    }
    if (current == null) continue;
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    final name = line.substring(0, colon);
    final value = line.substring(colon + 1);
    // 同名属性取第一条（DTSTART 等不该重复；重复时首个更接近真实）
    final key = name.split(';').first.toUpperCase();
    current!.putIfAbsent(key, () => value);
    // DTSTART/DTEND 需要参数（VALUE=DATE / TZID）——单独记原始「名;参」行
    if (key == 'DTSTART' || key == 'DTEND' || key == 'UID' || key == 'SUMMARY'
        || key == 'DESCRIPTION' || key == 'LOCATION' || key == 'RRULE') {
      current!.putIfAbsent('_raw_$key', () => line);
    }
  }
  // 文本末尾没有 END:VEVENT 的残块按规范丢弃（不猜）
  return IcsParseResult(events: events, skipped: skipped);
}

IcsEvent? _toEvent(Map<String, String> props) {
  final rawStart = props['_raw_DTSTART'];
  if (rawStart == null) return null;
  // 有 RRULE 的重复事件：本卡不展开（宁可跳过，也不落一条时间错误的事件）
  if (props.containsKey('RRULE')) return null;

  final start = _parseDateTime(rawStart);
  if (start == null) return null;
  final rawEnd = props['_raw_DTEND'];
  final end = rawEnd == null ? null : _parseDateTime(rawEnd);
  final uid = props['UID']?.trim();
  return IcsEvent(
    uid: (uid == null || uid.isEmpty)
        ? '${start.millisecondsSinceEpoch}-${props['SUMMARY'] ?? ''}'
        : uid,
    title: _unescape(props['SUMMARY'] ?? '') ?? '',
    start: start,
    end: end,
    allDay: rawStart.toUpperCase().contains('VALUE=DATE'),
    description: _unescape(props['DESCRIPTION'] ?? ''),
    location: _unescape(props['LOCATION'] ?? ''),
  );
}

/// `DTSTART;VALUE=DATE:20261029` / `DTSTART:20261029T090000Z` / `DTSTART;TZID=…:20261029T090000`
DateTime? _parseDateTime(String rawLine) {
  final colon = rawLine.indexOf(':');
  if (colon <= 0) return null;
  final params = rawLine.substring(0, colon).toUpperCase();
  final value = rawLine.substring(colon + 1).trim();
  if (params.contains('VALUE=DATE') && !params.contains('VALUE=DATE-TIME')) {
    if (value.length < 8) return null;
    final y = int.tryParse(value.substring(0, 4));
    final m = int.tryParse(value.substring(4, 6));
    final d = int.tryParse(value.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
  if (value.length < 15) return null;
  final y = int.tryParse(value.substring(0, 4));
  final mo = int.tryParse(value.substring(4, 6));
  final d = int.tryParse(value.substring(6, 8));
  final h = int.tryParse(value.substring(9, 11));
  final mi = int.tryParse(value.substring(11, 13));
  final s = int.tryParse(value.substring(13, 15));
  if (y == null || mo == null || d == null || h == null || mi == null) {
    return null;
  }
  // 结尾 Z = UTC：**必须用 DateTime.utc 构造**，而不是 `DateTime(...).toUtc()`——
  // 后者先按本地时区解释再换算，会把 09:00Z 在 UTC-4 变成 13:00Z（本测试抓到的）。
  final isUtc = value.toUpperCase().endsWith('Z');
  // 带 TZID 的按本地墙钟处理（不猜时区，避免把事件挪到别的日子）
  return isUtc
      ? DateTime.utc(y, mo, d, h, mi, s ?? 0)
      : DateTime(y, mo, d, h, mi, s ?? 0);
}

/// RFC 5545 文本转义：`\\n` 换行、`\\,` 逗号、`\\;` 分号、`\\\\` 反斜杠。
String? _unescape(String? value) {
  if (value == null) return null;
  return value
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\');
}
