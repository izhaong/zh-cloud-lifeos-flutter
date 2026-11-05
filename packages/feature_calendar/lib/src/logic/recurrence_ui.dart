/// 重复规则 UI ↔ RRULE 纯逻辑（契约 §2.2 rrule、§3.2.1；F-10）。
///
/// 生成的字符串不含 `RRULE:` 前缀（与服务端 ical4j / kernel `rrule` 包一致）。
library;

const String kFreqDaily = 'DAILY';
const String kFreqWeekly = 'WEEKLY';
const String kFreqMonthly = 'MONTHLY';
const String kFreqYearly = 'YEARLY';

/// BYDAY 星期缩写（RFC 5545；1=周一 … 7=周日）。
const List<String> kWeekdayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

/// 月份「第几个星期几」选项（-1 = 最后一个）。
const List<int> kOrdinalChoices = [1, 2, 3, 4, -1];

/// 预设下拉值（UI 用；自定义单独打开编辑器）。
enum RecurrencePreset {
  none('不重复'),
  daily('每天'),
  weekly('每周'),
  biweekly('每两周'),
  monthly('每月'),
  yearly('每年'),
  custom('自定义');

  const RecurrencePreset(this.label);

  final String label;
}

/// 重复编辑器状态（F-10 自定义页）。
class RecurrenceConfig {
  RecurrenceConfig({
    this.freq = kFreqWeekly,
    this.interval = 1,
    Set<int>? weekdays,
    this.monthlyByDayOfMonth = true,
    this.monthDay,
    this.ordinal = 1,
    this.ordinalWeekday = 1,
    this.until,
    this.count,
  }) : weekdays = weekdays ?? <int>{};

  /// DAILY / WEEKLY / MONTHLY / YEARLY。
  String freq;
  int interval;

  /// WEEKLY 的周几（1=周一…7=周日）；空 = 由开始日期推导。
  Set<int> weekdays;

  /// MONTHLY：true = 每月同日；false = 每月第 N 个周 X。
  bool monthlyByDayOfMonth;
  int? monthDay;
  int ordinal;
  int ordinalWeekday;

  /// 结束：until 与 count 互斥（都为空 = 永不）。
  DateTime? until;
  int? count;

  bool get isNeverEnd => until == null && count == null;
}

/// 预设 → RRULE（[startAt] 用于推导周几/月日；none 回 null）。
String? rruleForPreset(RecurrencePreset preset, DateTime startAt) {
  final wall = startAt.toUtc();
  switch (preset) {
    case RecurrencePreset.none:
      return null;
    case RecurrencePreset.daily:
      return 'FREQ=DAILY';
    case RecurrencePreset.weekly:
      return 'FREQ=WEEKLY;BYDAY=${kWeekdayCodes[wall.weekday - 1]}';
    case RecurrencePreset.biweekly:
      return 'FREQ=WEEKLY;INTERVAL=2;BYDAY=${kWeekdayCodes[wall.weekday - 1]}';
    case RecurrencePreset.monthly:
      return 'FREQ=MONTHLY;BYMONTHDAY=${wall.day}';
    case RecurrencePreset.yearly:
      return 'FREQ=YEARLY;BYMONTH=${wall.month};BYMONTHDAY=${wall.day}';
    case RecurrencePreset.custom:
      return null;
  }
}

/// 配置 → RRULE 字符串（不含前缀）。
String buildRRule(RecurrenceConfig c, DateTime startAt) {
  final parts = <String>['FREQ=${c.freq}'];
  if (c.interval > 1) {
    parts.add('INTERVAL=${c.interval}');
  }
  if (c.freq == kFreqWeekly) {
    final days = c.weekdays.isEmpty
        ? {startAt.toUtc().weekday}
        : (c.weekdays.toList()..sort());
    parts.add('BYDAY=${days.map((d) => kWeekdayCodes[d - 1]).join(',')}');
  } else if (c.freq == kFreqMonthly) {
    if (c.monthlyByDayOfMonth) {
      parts.add('BYMONTHDAY=${c.monthDay ?? startAt.toUtc().day}');
    } else {
      final ord = c.ordinal == -1 ? '-1' : '${c.ordinal}';
      parts.add('BYDAY=$ord${kWeekdayCodes[c.ordinalWeekday - 1]}');
    }
  } else if (c.freq == kFreqYearly) {
    parts.add('BYMONTH=${startAt.toUtc().month}');
    parts.add('BYMONTHDAY=${startAt.toUtc().day}');
  }
  if (c.count != null) {
    parts.add('COUNT=${c.count}');
  } else if (c.until != null) {
    final u = c.until!.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    parts.add('UNTIL=${u.year}${two(u.month)}${two(u.day)}'
        'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z');
  }
  return parts.join(';');
}

/// RRULE → 下拉预设（不能归入预设时回 custom）。
RecurrencePreset presetOf(String? rrule) {
  if (rrule == null || rrule.trim().isEmpty) {
    return RecurrencePreset.none;
  }
  final map = _parseParts(rrule);
  final freq = map['FREQ'];
  final interval = int.tryParse(map['INTERVAL'] ?? '1') ?? 1;
  final hasEnd = map.containsKey('COUNT') || map.containsKey('UNTIL');
  if (hasEnd || map.containsKey('BYSETPOS')) {
    return RecurrencePreset.custom;
  }
  switch (freq) {
    case kFreqDaily:
      return interval == 1 ? RecurrencePreset.daily : RecurrencePreset.custom;
    case kFreqWeekly:
      final byDay = map['BYDAY'];
      final single = byDay == null || !byDay.contains(',');
      if (!single) {
        return RecurrencePreset.custom;
      }
      if (interval == 1) {
        return RecurrencePreset.weekly;
      }
      return interval == 2 ? RecurrencePreset.biweekly : RecurrencePreset.custom;
    case kFreqMonthly:
      final simple = !map.containsKey('BYDAY');
      return interval == 1 && simple
          ? RecurrencePreset.monthly
          : RecurrencePreset.custom;
    case kFreqYearly:
      return interval == 1 ? RecurrencePreset.yearly : RecurrencePreset.custom;
    default:
      return RecurrencePreset.custom;
  }
}

/// RRULE → 编辑器初始状态（best-effort；无法解析的键忽略）。
RecurrenceConfig parseRRule(String? rrule, DateTime startAt) {
  final wall = startAt.toUtc();
  final map = rrule == null ? <String, String>{} : _parseParts(rrule);
  final freq = map['FREQ'] ?? kFreqWeekly;
  final config = RecurrenceConfig(
    freq: freq,
    interval: int.tryParse(map['INTERVAL'] ?? '1') ?? 1,
    monthDay: int.tryParse(map['BYMONTHDAY'] ?? '') ?? wall.day,
    count: int.tryParse(map['COUNT'] ?? ''),
  );
  final byDay = map['BYDAY'];
  if (byDay != null && !byDay.contains(',')) {
    final code = byDay.substring(byDay.length - 2);
    final idx = kWeekdayCodes.indexOf(code);
    if (idx >= 0) {
      config.weekdays = {idx + 1};
      config.ordinalWeekday = idx + 1;
    }
    final prefix = byDay.substring(0, byDay.length - 2);
    final ord = int.tryParse(prefix);
    if (ord != null) {
      config.monthlyByDayOfMonth = false;
      config.ordinal = ord;
    }
  } else if (byDay != null) {
    for (final token in byDay.split(',')) {
      final idx = kWeekdayCodes.indexOf(token);
      if (idx >= 0) {
        config.weekdays.add(idx + 1);
      }
    }
  }
  final until = map['UNTIL'];
  if (until != null) {
    config.until = _parseUntil(until);
  }
  return config;
}

/// 重复规则的人类可读标签（Repeat 行 trailing）。
String recurrenceLabel(String? rrule) {
  final preset = presetOf(rrule);
  return preset.label;
}

Map<String, String> _parseParts(String rrule) {
  final map = <String, String>{};
  for (final part in rrule.trim().split(';')) {
    final i = part.indexOf('=');
    if (i > 0) {
      map[part.substring(0, i).toUpperCase()] = part.substring(i + 1);
    }
  }
  return map;
}

DateTime? _parseUntil(String value) {
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$')
      .firstMatch(value);
  if (m == null) {
    return null;
  }
  return DateTime.utc(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6)!),
  );
}
