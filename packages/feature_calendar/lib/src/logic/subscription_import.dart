// 订阅日历的内容拉取（#403）。
//
// 此前「添加订阅」只写 `Calendar.sourceUrl`，**不发请求**，订阅后永远不会出现事件。
// 这里补上「抓取 → 解析 → 落库」这一段；抓取走可注入的 [SubscriptionFetcher]
// （开源包不直接依赖 HTTP），因此单测可以用假实现，不碰真实网络。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../models/ics_event.dart';
import '../providers.dart';
import 'ics_parser.dart';

/// 一次订阅刷新的结果（如实回报，UI 据此提示）。
class SubscriptionImportResult {
  const SubscriptionImportResult({
    required this.imported,
    required this.skipped,
    this.error,
    this.pending = false,
  });

  /// 抓取端口未注入（开源包默认不联网）：URL 已存，内容待同步。
  const SubscriptionImportResult.pending()
      : imported = 0,
        skipped = 0,
        error = null,
        pending = true;

  const SubscriptionImportResult.failed(String message)
      : imported = 0,
        skipped = 0,
        error = message,
        pending = false;

  final int imported;
  final int skipped;

  /// 抓取/解析失败的原因（null = 成功）。
  final String? error;

  /// 端口未注入，内容尚未拉取（不是失败）。
  final bool pending;

  bool get isFailure => error != null;
}

/// 抓取并落库某个订阅日历的内容。
///
/// - 事件 id 用 `sub-<uid>`，**重复刷新是幂等的**（upsert 覆盖，不产生重复行）；
/// - 失败的条目（缺 DTSTART、带 RRULE）计入 `skipped`，不静默丢弃；
/// - 抓取失败**不删**已有事件（离线/临时 500 不该清空用户的订阅）。
Future<SubscriptionImportResult> refreshSubscription({
  required CalendarRepository repository,
  required Calendar calendar,
  required SubscriptionFetcher fetcher,
  required DateTime Function() clock,
}) async {
  final url = calendar.sourceUrl;
  if (url == null || url.isEmpty) {
    return const SubscriptionImportResult(imported: 0, skipped: 0);
  }
  // 归属边界（#443 ADR，`docs/lifeos/calendar/plan/adr-ics-parser-ownership.md`）：
  //
  // - `remoteId == null` → **客户端本地订阅**，客户端自己抓 .ics 并解析（本文件）；
  // - `remoteId != null` → **服务端订阅**，事件随云同步下发（ical4j 在服务端解析），
  //   客户端**不得**再抓一遍，否则同一份 .ics 会落两套事件（`sub-<uid>` +
  //   服务端 uid），月视图里出现双份。
  //
  // `_buildLocalMutations` 只推 `remoteId == null && kind == local`，所以本地订阅
  // 永远不会上传成服务端订阅——这两条路是**不相交**的，边界必须在这里守住。
  if (calendar.remoteId != null) {
    return const SubscriptionImportResult.pending();
  }
  final String raw;
  try {
    raw = await fetcher.fetch(url);
  } catch (e) {
    return SubscriptionImportResult.failed('抓取失败：$e');
  }
  final parsed = parseIcs(raw);
  final now = clock();
  for (final event in parsed.events) {
    await repository.upsertEvent(
      _toCalendarEvent(event, calendar.id, now),
    );
  }
  return SubscriptionImportResult(
    imported: parsed.events.length,
    skipped: parsed.skipped,
  );
}

CalendarEvent _toCalendarEvent(IcsEvent event, String calendarId, DateTime now) {
  final start = event.start;
  final end = event.end ??
      (event.allDay
          ? start.add(const Duration(days: 1))
          : start.add(const Duration(hours: 1)));
  return CalendarEvent(
    id: 'sub-${event.uid}',
    calendarId: calendarId,
    uid: event.uid,
    title: event.title.isEmpty ? '未命名事件' : event.title,
    startAt: start,
    endAt: end,
    allDay: event.allDay,
    timeZone: start.isUtc ? 'UTC' : 'local',
    notes: event.description,
    location: event.location,
    updatedAt: now,
  );
}
