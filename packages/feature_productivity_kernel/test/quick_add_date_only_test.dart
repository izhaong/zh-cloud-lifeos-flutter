import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// parity#183：00:00 = 「只有日期」，逾期只按天算；带时刻的才按时间点算。
void main() {
  late InMemoryReminderRepository repo;

  setUp(() async {
    repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '个人'));
  });

  Future<int> count(String listId) async =>
      (await repo.watchItems(listId: listId).first).length;

  test('只有日期（今天 00:00）不算紧急，但仍在「今天」', () async {
    final now = DateTime.now();
    await repo.upsertItem(
      ReminderItem(
        id: 'r1',
        listId: 'list.a',
        title: '买牛奶',
        dueAt: DateTime(now.year, now.month, now.day),
      ),
    );

    expect(await count('smart.today'), 1);
    expect(await count('smart.urgent'), 0, reason: '只有日期的今天到期不该变红');
  });

  test('只有日期且日期已过 → 紧急', () async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    await repo.upsertItem(
      ReminderItem(
        id: 'r2',
        listId: 'list.a',
        title: '过期项',
        dueAt: DateTime(yesterday.year, yesterday.month, yesterday.day),
      ),
    );

    expect(await count('smart.urgent'), 1);
  });

  test('带时刻且已过点 → 紧急（Apple 定时提醒到点即过期）', () async {
    final now = DateTime.now();
    final past = DateTime(now.year, now.month, now.day, now.hour, now.minute)
        .subtract(const Duration(minutes: 5));
    await repo.upsertItem(
      ReminderItem(
        id: 'r3',
        listId: 'list.a',
        title: '定时项',
        dueAt: past,
      ),
    );

    expect(await count('smart.urgent'), 1, reason: '有时刻的仍按时间点判过期');
  });
}
