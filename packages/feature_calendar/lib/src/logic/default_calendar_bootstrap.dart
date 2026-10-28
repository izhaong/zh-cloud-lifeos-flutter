import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// 首启/空库兜底：保证至少有一条本地日历并标记为默认（Apple 首启即带
/// 「日历」默认日历；否则新建日程会卡在「没有可用日历，无法保存」，
/// 见 parity#156）。
///
/// 幂等：已有默认日历（且未软删）直接返回；有本地日历但没有默认 → 把
/// 排序最前的一条设为默认；一条本地日历都没有 → 建一条「日历」。
Future<Calendar?> ensureDefaultCalendar(CalendarRepository repo) async {
  final all = await repo.watchCalendars().first;
  final local = all
      .where((c) => c.kind == CalendarKind.local && c.deletedAt == null)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  if (local.isEmpty) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final calendar = Calendar(
      id: 'cal-default-$now',
      title: '日历',
      // Apple 默认日历红（契约 §8.1 预设色 systemRed）。
      colorArgb: 0xFFFF3B30,
      isDefault: true,
    );
    await repo.upsertCalendar(calendar);
    return calendar;
  }
  for (final c in local) {
    if (c.isDefault) return c;
  }
  await repo.setDefaultCalendar(local.first.id);
  return local.first;
}
