// #448：手动时区下的「有效当下」。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('#448 跟随系统（null/空串）原样返回', () {
    final now = DateTime(2026, 10, 29, 15, 30);
    expect(effectiveNow(now, null), now);
    expect(effectiveNow(now, ''), now);
  });

  test('#448 同一瞬时，上海与纽约的「今天」不同', () {
    // 2026-10-29T23:30Z：上海已是 30 日 07:30，纽约还是 29 日 19:30
    final instant = DateTime.utc(2026, 10, 29, 23, 30);
    final shanghai = effectiveNow(instant, 'Asia/Shanghai');
    final newYork = effectiveNow(instant, 'America/New_York');

    expect((shanghai.year, shanghai.month, shanghai.day), (2026, 10, 30));
    expect((newYork.year, newYork.month, newYork.day), (2026, 10, 29));
  });

  test('#448 时区换算保留时分（墙钟值，不是 UTC 偏移后的时刻）', () {
    final instant = DateTime.utc(2026, 10, 29, 23, 30);
    final shanghai = effectiveNow(instant, 'Asia/Shanghai');
    expect((shanghai.hour, shanghai.minute), (7, 30));
  });

  test('#448 非法时区名回落系统时间（不抛）', () {
    final now = DateTime(2026, 10, 29, 15, 30);
    expect(effectiveNow(now, 'Not/AZone'), now);
  });

  test('#448 nowProvider 影响 smart.today 归属（仓储接缝）', () async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    // 上海 30 日 07:30 的那条，在「纽约现在」视角下属于 29 日
    await repo.upsertItem(ReminderItem(
      id: 'i1',
      listId: 'list.work',
      title: '跨日项',
      dueAt: DateTime(2026, 10, 30, 7, 30),
    ));
    repo.nowProvider = () => DateTime(2026, 10, 29, 19, 30);

    final today = await repo.watchItems(listId: 'smart.today').first;
    expect(today.map((e) => e.id), isNot(contains('i1')),
        reason: '有效当下是 29 日，30 日的项不该在「今天」');

    repo.nowProvider = () => DateTime(2026, 10, 30, 7, 30);
    final today2 = await repo.watchItems(listId: 'smart.today').first;
    expect(today2.map((e) => e.id), contains('i1'));
  });
}
