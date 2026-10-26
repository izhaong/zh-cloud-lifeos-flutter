/// 自然语言快速事件解析（契约 §6；F-12）。
///
/// 确定性规则、不调用 AI；按契约顺序：日期 → 时间 → 区间 → 多日 → 全天。
library;

import '../logic/event_time.dart';

/// 解析结果（UTC 时刻）。
class QuickEvent {
  const QuickEvent({
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.allDay,
  });

  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;

  @override
  String toString() => 'QuickEvent($title, $startAt, $endAt, allDay=$allDay)';
}

const Map<String, int> _cnWeekdays = {
  '一': 1,
  '二': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '日': 7,
  '天': 7,
};

const Map<String, int> _enWeekdays = {
  'mon': 1,
  'tue': 2,
  'wed': 3,
  'thu': 4,
  'fri': 5,
  'sat': 6,
  'sun': 7,
};

const Map<String, int> _enMonths = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// 解析入口。[now] 传设备本地墙钟（测试可固定）。
QuickEvent? parseQuickEvent(
  String input, {
  required DateTime now,
  int defaultDurationMinutes = 60,
  String timeZone = 'UTC',
}) {
  final raw = input.trim();
  if (raw.isEmpty) {
    return null; // TC-CAL-KR-310
  }
  var working = raw;

  /// 命中片段从 working 抹掉（后续正则与标题都不再看到它）。
  void take(String matched) {
    final idx = working.indexOf(matched);
    if (idx >= 0) {
      working = working.replaceRange(
          idx, idx + matched.length, ' ' * matched.length);
    }
  }

  // ---- 1. 多日（周一到周五 / Mon-Fri；契约 §6 第 4 条） ----
  final cnMulti = RegExp(
      r'(?:周|星期)\s*([一二三四五六日天])\s*(?:到|至|-|~)\s*(?:周|星期)?\s*([一二三四五六日天])');
  final enMulti = RegExp(
      r'\b(mon|tue|wed|thu|fri|sat|sun)[a-z]*\s*[-–~]\s*(mon|tue|wed|thu|fri|sat|sun)[a-z]*\b',
      caseSensitive: false);
  final cnMultiMatch = cnMulti.firstMatch(working);
  final enMultiMatch = enMulti.firstMatch(working);
  final multi = cnMultiMatch ?? enMultiMatch;
  if (multi != null) {
    final isCn = cnMultiMatch != null;
    final startWeekday = isCn
        ? _cnWeekdays[multi.group(1)!]!
        : _enWeekdays[multi.group(1)!.toLowerCase()]!;
    final endWeekday = isCn
        ? _cnWeekdays[multi.group(2)!]!
        : _enWeekdays[multi.group(2)!.toLowerCase()]!;
    take(multi.group(0)!);
    final startDay = _nextWeekday(now, startWeekday);
    var endDay = startDay;
    var guard = 0;
    while (endDay.weekday != endWeekday && guard < 14) {
      endDay = endDay.add(const Duration(days: 1));
      guard++;
    }
    final startWall = DateTime(startDay.year, startDay.month, startDay.day);
    final endWall = DateTime(endDay.year, endDay.month, endDay.day + 1);
    return QuickEvent(
      title: _cleanTitle(working),
      startAt: utcFromWall(startWall, timeZone),
      endAt: utcFromWall(endWall, timeZone),
      allDay: true,
    );
  }

  // ---- 2. 日期（契约 §6 第 1 条） ----
  DateTime? date;
  var isWeekdayDate = false;
  var weekdayMatchedToday = false;

  DateTime dateInYear(int month, int day) {
    final candidate = DateTime(now.year, month, day);
    final today = DateTime(now.year, now.month, now.day);
    return candidate.isBefore(today)
        ? DateTime(now.year + 1, month, day)
        : candidate;
  }

  final ymd = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(working);
  final cnMonthDay =
      RegExp(r'(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]').firstMatch(working);
  final enMonth = RegExp(
          r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2})\b',
          caseSensitive: false)
      .firstMatch(working);
  final slash =
      RegExp(r'(?<![\d:])(\d{1,2})/(\d{1,2})(?![\d:])').firstMatch(working);

  if (ymd != null) {
    take(ymd.group(0)!);
    date = DateTime(int.parse(ymd.group(1)!), int.parse(ymd.group(2)!),
        int.parse(ymd.group(3)!));
  } else if (cnMonthDay != null) {
    take(cnMonthDay.group(0)!);
    date = dateInYear(
        int.parse(cnMonthDay.group(1)!), int.parse(cnMonthDay.group(2)!));
  } else if (enMonth != null) {
    take(enMonth.group(0)!);
    date = dateInYear(_enMonths[enMonth.group(1)!.toLowerCase()]!,
        int.parse(enMonth.group(2)!));
  } else if (slash != null) {
    take(slash.group(0)!);
    date =
        dateInYear(int.parse(slash.group(1)!), int.parse(slash.group(2)!));
  } else {
    final relative = RegExp(r'(今天|明天|后天|大后天)').firstMatch(working);
    final nextWeek =
        RegExp(r'下\s*(?:周|星期)\s*([一二三四五六日天])').firstMatch(working);
    final plainWeek =
        RegExp(r'(?:周|星期)\s*([一二三四五六日天])').firstMatch(working);
    final enNext = RegExp(
            r'\bnext\s+(mon|tue|wed|thu|fri|sat|sun)[a-z]*\b',
            caseSensitive: false)
        .firstMatch(working);
    final enPlain = RegExp(
            r'\b(mon|tue|wed|thu|fri|sat|sun)[a-z]*\b',
            caseSensitive: false)
        .firstMatch(working);
    final enToday = RegExp(r'\b(today|tomorrow)\b', caseSensitive: false)
        .firstMatch(working);

    if (relative != null) {
      take(relative.group(0)!);
      final offset = switch (relative.group(1)!) {
        '今天' => 0,
        '明天' => 1,
        '后天' => 2,
        _ => 3,
      };
      date = DateTime(now.year, now.month, now.day + offset);
    } else if (nextWeek != null) {
      take(nextWeek.group(0)!);
      date = _nextWeekday(now, _cnWeekdays[nextWeek.group(1)!]!,
          nextWeekOnly: true);
      isWeekdayDate = true;
    } else if (plainWeek != null) {
      take(plainWeek.group(0)!);
      date = _nextWeekday(now, _cnWeekdays[plainWeek.group(1)!]!);
      isWeekdayDate = true;
      weekdayMatchedToday = _sameDay(date, now);
    } else if (enNext != null) {
      take(enNext.group(0)!);
      date = _nextWeekday(now, _enWeekdays[enNext.group(1)!.toLowerCase()]!,
          nextWeekOnly: true);
      isWeekdayDate = true;
    } else if (enPlain != null) {
      take(enPlain.group(0)!);
      date = _nextWeekday(now, _enWeekdays[enPlain.group(1)!.toLowerCase()]!);
      isWeekdayDate = true;
      weekdayMatchedToday = _sameDay(date, now);
    } else if (enToday != null) {
      take(enToday.group(0)!);
      final word = enToday.group(1)!.toLowerCase();
      date = DateTime(
          now.year, now.month, now.day + (word == 'tomorrow' ? 1 : 0));
    }
  }

  // ---- 3. 时间 / 区间（契约 §6 第 2、3 条） ----
  const period = r'(上午|下午|晚上|中午)';
  const token =
      r'(?:' + period + r'\s*)?(\d{1,2})(?::(\d{2}))?\s*(?:点\s*(半|(\d{1,2})\s*分)?)?\s*(am|pm)?';
  final rangeRe =
      RegExp('$token\\s*(?:到|至|-|–|~)\\s*$token', caseSensitive: false);
  final range = rangeRe.firstMatch(working);

  DateTime? timeStart;
  DateTime? timeEnd;

  int hourOf(String? per, String hour, String? minute, String? mark) {
    var h = int.parse(hour);
    final m = minute == null ? 0 : int.parse(minute);
    final pm = mark?.toLowerCase() == 'pm' ||
        per == '下午' ||
        per == '晚上' ||
        (per == '中午' && h < 11);
    final am = mark?.toLowerCase() == 'am' || per == '上午';
    if (!pm && !am && h <= 7 && h != 0) {
      h += 12; // 「at 6」「6-7」默认傍晚
    }
    if (pm && h < 12) {
      h += 12;
    }
    if (am && h == 12) {
      h = 0;
    }
    return h * 60 + m;
  }

  int? parseTokenMinutes(Match m, int offset) {
    final per = m.group(offset);
    final hour = m.group(offset + 1);
    if (hour == null) {
      return null;
    }
    final minute = m.group(offset + 2);
    final half = m.group(offset + 3);
    final fen = m.group(offset + 4);
    final mark = m.group(offset + 5);
    final minutes = hourOf(per, hour, minute, mark);
    if (half == '半') {
      return (minutes ~/ 60) * 60 + 30;
    }
    if (fen != null) {
      return (minutes ~/ 60) * 60 + int.parse(fen);
    }
    return minutes;
  }

  if (range != null) {
    final a = parseTokenMinutes(range, 1);
    final b = parseTokenMinutes(range, 7);
    if (a != null && b != null) {
      take(range.group(0)!);
      var endMinutes = b;
      if (endMinutes <= a) {
        endMinutes += 12 * 60;
      }
      timeStart = _minutesToWall(date ?? now, a);
      timeEnd = _minutesToWall(date ?? now, endMinutes);
    }
  }

  if (timeStart == null) {
    final single =
        RegExp('(?:\\bat\\s+)?$token', caseSensitive: false)
            .firstMatch(working);
    final candidate = single?.group(0) ?? '';
    final hasHint = candidate.contains('点') ||
        candidate.contains(':') ||
        RegExp(r'(am|pm|\bat\s)', caseSensitive: false).hasMatch(candidate);
    if (single != null &&
        hasHint &&
        RegExp(r'\d').hasMatch(candidate)) {
      final minutes = parseTokenMinutes(single, 1);
      if (minutes != null) {
        take(candidate.trim());
        timeStart = _minutesToWall(date ?? now, minutes);
      }
    }
  }

  // ---- 4. 组装 ----
  final day = date ?? DateTime(now.year, now.month, now.day);
  if (timeStart == null) {
    final startWall = DateTime(day.year, day.month, day.day);
    final endWall = DateTime(day.year, day.month, day.day + 1);
    return QuickEvent(
      title: _cleanTitle(working),
      startAt: utcFromWall(startWall, timeZone),
      endAt: utcFromWall(endWall, timeZone),
      allDay: true,
    );
  }

  var startWall = timeStart;
  var endWall = timeEnd ??
      startWall.add(Duration(minutes: defaultDurationMinutes));

  // 星期几命中今天但时间已过 → 顺延一周（TC-CAL-KR-302）
  if (isWeekdayDate && weekdayMatchedToday && _wallNotAfter(endWall, now)) {
    startWall = startWall.add(const Duration(days: 7));
    endWall = endWall.add(const Duration(days: 7));
  }

  return QuickEvent(
    title: _cleanTitle(working),
    startAt: utcFromWall(startWall, timeZone),
    endAt: utcFromWall(endWall, timeZone),
    allDay: false,
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 墙上时间比较（避免宿主时区/UTC 标记把 13:00 与 14:00Z 混比）。
bool _wallNotAfter(DateTime a, DateTime b) {
  final x = [a.year, a.month, a.day, a.hour, a.minute, a.second];
  final y = [b.year, b.month, b.day, b.hour, b.minute, b.second];
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) {
      return x[i] < y[i];
    }
  }
  return true;
}

DateTime _nextWeekday(DateTime now, int weekday,
    {bool nextWeekOnly = false}) {
  final today = DateTime(now.year, now.month, now.day);
  if (nextWeekOnly) {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return monday.add(Duration(days: 7 + weekday - 1));
  }
  final delta = (weekday - now.weekday + 7) % 7;
  return today.add(Duration(days: delta));
}

DateTime _minutesToWall(DateTime day, int minutes) {
  final base = DateTime(day.year, day.month, day.day);
  return base.add(Duration(minutes: minutes));
}

String _cleanTitle(String text) {
  var result = text
      .replaceAll(RegExp(r'\b(on|at|from|to)\b', caseSensitive: false), ' ')
      .replaceAll('的', ' ')
      .replaceAll(RegExp(r'[，,。;；]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (result.isEmpty) {
    result = '新日程';
  }
  return result;
}
