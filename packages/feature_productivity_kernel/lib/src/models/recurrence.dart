/// 提醒重复规则（P0 五预设；自定义 RRULE/结束日期/完成历史记 P1）。
enum Recurrence {
  daily,
  weekly,
  monthly,
  yearly,
  weekdays;

  String get id => name;

  static Recurrence? fromId(String? id) {
    if (id == null) return null;
    for (final r in Recurrence.values) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// 下一次到期时间（纯函数，无 IO/时钟读取）。
  ///
  /// 从 [from]（当前 dueAt）推进一次；[now] 只用于 overdue 推进：
  /// 反复 +1 周期直到结果晚于 [now]，避免逾期条目完成后立刻又出现在「今天」。
  DateTime nextOccurrence(DateTime from, DateTime now) {
    var next = _advance(from);
    // overdue：完成时滚动到未来（保护上限 512 次防死循环）
    var guard = 0;
    while (!next.isAfter(now) && guard < 512) {
      next = _advance(next);
      guard++;
    }
    return next;
  }

  DateTime _advance(DateTime t) {
    return switch (this) {
      Recurrence.daily => DateTime(t.year, t.month, t.day + 1, t.hour,
          t.minute),
      Recurrence.weekly => DateTime(t.year, t.month, t.day + 7, t.hour,
          t.minute),
      Recurrence.monthly => DateTime(t.year, t.month + 1, _clampDay(
          t.year, t.month + 1, t.day), t.hour, t.minute),
      Recurrence.yearly => DateTime(t.year + 1, t.month, _clampDay(
          t.year + 1, t.month, t.day), t.hour, t.minute),
      Recurrence.weekdays => _nextWeekday(t),
    };
  }

  /// 工作日：跳过周六周日。
  DateTime _nextWeekday(DateTime t) {
    var next = DateTime(t.year, t.month, t.day + 1, t.hour, t.minute);
    while (next.weekday == DateTime.saturday ||
        next.weekday == DateTime.sunday) {
      next = DateTime(next.year, next.month, next.day + 1, next.hour,
          next.minute);
    }
    return next;
  }

  /// 月末钳制：如 1 月 31 日 → 2 月 28/29 日。
  static int _clampDay(int year, int month, int day) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return day > daysInMonth ? daysInMonth : day;
  }
}

/// 唯一 id 工厂（收敛到 kernel；UI/仓库禁止手拼 id）。
String newReminderId() => 'rem_${DateTime.now().microsecondsSinceEpoch}_'
    '${_shortRand()}';

String newListId() => 'list_${DateTime.now().microsecondsSinceEpoch}_'
    '${_shortRand()}';

String _shortRand() {
  final rand = DateTime.now().microsecondsSinceEpoch.hashCode;
  return (rand & 0xFFFF).toRadixString(36);
}
