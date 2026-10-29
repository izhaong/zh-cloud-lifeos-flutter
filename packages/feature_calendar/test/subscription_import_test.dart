// TC-CAL-UI-152 / C1 订阅日历（#403）：保存后真的抓取并落库。
//
// 此前「添加订阅」只写 sourceUrl，**不发请求**——订阅后永远没有事件。
// 本测试用假 fetcher（不打真实网络），验证「抓取 → 解析 → 落库 → 幂等」。
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements CalendarRepository {
  final List<CalendarEvent> events = [];

  @override
  Future<String> upsertEvent(
    CalendarEvent event, {
    DateTime? occurrenceStart,
    EditScope scope = EditScope.thisOnly,
  }) async {
    final i = events.indexWhere((e) => e.id == event.id);
    if (i >= 0) {
      events[i] = event;
    } else {
      events.add(event);
    }
    return event.id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Fetcher implements SubscriptionFetcher {
  _Fetcher(this.body);

  final String body;
  Object? error;
  final List<String> urls = [];

  @override
  Future<String> fetch(String url) async {
    urls.add(url);
    if (error != null) throw error!;
    return body;
  }
}

const _ics = '''
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:sub-a
SUMMARY:订阅事件一
DTSTART:20261029T090000Z
DTEND:20261029T100000Z
END:VEVENT
BEGIN:VEVENT
UID:sub-b
SUMMARY:订阅事件二
DTSTART;VALUE=DATE:20261101
END:VEVENT
BEGIN:VEVENT
UID:sub-bad
SUMMARY:没有开始时间
END:VEVENT
END:VCALENDAR''';

Calendar _subscription() => const Calendar(
      id: 'cal-sub',
      title: '订阅',
      colorArgb: 0xFF007AFF,
      kind: CalendarKind.subscription,
      sourceUrl: 'https://example.test/feed.ics',
    );

void main() {
  test('#403 抓取并按 UID 落库；跳过的条目计数', () async {
    final repo = _Repo();
    final fetcher = _Fetcher(_ics);

    final result = await refreshSubscription(
      repository: repo,
      calendar: _subscription(),
      fetcher: fetcher,
      clock: () => DateTime(2026, 10, 29, 12),
    );

    expect(fetcher.urls, ['https://example.test/feed.ics']);
    expect(result.imported, 2);
    expect(result.skipped, 1, reason: '缺 DTSTART 的那条要计入 skipped，不能静默丢');
    expect(repo.events.map((e) => e.id), containsAll(['sub-sub-a', 'sub-sub-b']));
    expect(repo.events.firstWhere((e) => e.id == 'sub-sub-b').allDay, isTrue);
  });

  test('#403 重复刷新幂等（同 UID 不产生重复行）', () async {
    final repo = _Repo();
    final fetcher = _Fetcher(_ics);

    await refreshSubscription(
      repository: repo,
      calendar: _subscription(),
      fetcher: fetcher,
      clock: () => DateTime(2026, 10, 29, 12),
    );
    await refreshSubscription(
      repository: repo,
      calendar: _subscription(),
      fetcher: fetcher,
      clock: () => DateTime(2026, 10, 29, 13),
    );

    expect(repo.events, hasLength(2), reason: '两次刷新仍只有两条');
  });

  test('#403 抓取失败：报错但不删已有事件（离线不清空订阅）', () async {
    final repo = _Repo();
    final good = _Fetcher(_ics);
    await refreshSubscription(
      repository: repo,
      calendar: _subscription(),
      fetcher: good,
      clock: () => DateTime(2026, 10, 29, 12),
    );
    expect(repo.events, hasLength(2));

    final failing = _Fetcher('')..error = StateError('network down');
    final result = await refreshSubscription(
      repository: repo,
      calendar: _subscription(),
      fetcher: failing,
      clock: () => DateTime(2026, 10, 29, 14),
    );

    expect(result.isFailure, isTrue);
    expect(result.error, contains('抓取失败'));
    expect(repo.events, hasLength(2), reason: '抓取失败不得清空已有事件');
  });

  test('#443 服务端订阅（remoteId != null）不由客户端抓取', () async {
    // 边界来自 ADR：remoteId != null 的订阅事件随云同步下发（服务端 ical4j 解析）；
    // 客户端再抓一遍会让同一份 .ics 落两套事件（sub-<uid> + 服务端 uid）。
    final repo = _Repo();
    final fetcher = _Fetcher(_ics);

    final result = await refreshSubscription(
      repository: repo,
      calendar: const Calendar(
        id: 'cal-server',
        title: '服务端订阅',
        colorArgb: 0xFF007AFF,
        kind: CalendarKind.subscription,
        sourceUrl: 'https://example.test/feed.ics',
        remoteId: '12345',
      ),
      fetcher: fetcher,
      clock: () => DateTime(2026, 10, 29),
    );

    expect(fetcher.urls, isEmpty, reason: '服务端订阅不该由客户端发起抓取');
    expect(repo.events, isEmpty, reason: '不该落客户端事件');
    expect(result.pending, isTrue);
  });

  test('#403 没有 sourceUrl 的日历不发起抓取', () async {
    final repo = _Repo();
    final fetcher = _Fetcher(_ics);

    final result = await refreshSubscription(
      repository: repo,
      calendar: const Calendar(id: 'c1', title: '本地', colorArgb: 0xFF007AFF),
      fetcher: fetcher,
      clock: () => DateTime(2026, 10, 29),
    );

    expect(fetcher.urls, isEmpty);
    expect(result.imported, 0);
  });
}