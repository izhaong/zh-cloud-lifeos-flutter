// #445：「今天」汇总通知的时点设置与调度。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/notifications/local_reminder_alert_scheduler.dart';

/// 记录 `zonedSchedule` / `cancel` 调用的假插件（与日历调度器测试同一套路）。
class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  final List<(int, DateTime, String)> scheduled = [];
  final List<int> cancelled = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #zonedSchedule) {
      final args = invocation.namedArguments;
      final id = args[#id] as int;
      final date = args[#scheduledDate] as dynamic;
      final body = args[#body] as String;
      scheduled.add((id, date.toLocal() as DateTime, body));
    }
    if (invocation.memberName == #cancel) {
      final args = invocation.namedArguments;
      cancelled.add(args[#id] as int? ?? 0);
    }
    return Future<bool?>.value(true);
  }
}

class _FakeRepository implements ReminderRepository {
  _FakeRepository(this.items);
  List<ReminderItem> items;

  @override
  Stream<List<ReminderItem>> watchItems({
    String? listId,
    bool includeCompleted = false,
  }) => Stream.value(items);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakePrefs implements TaskPreferenceRepository {
  _FakePrefs(this.pref);
  TaskPreference pref;

  @override
  Stream<TaskPreference> watchPreference() => Stream.value(pref);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

ReminderItem _item(String id, DateTime dueAt) => ReminderItem(
  id: id,
  listId: 'l1',
  title: id,
  dueAt: dueAt,
);

List<(int, DateTime, String)> _summary(_RecordingPlugin plugin) => plugin.scheduled
    .where((e) => e.$1 == LocalReminderAlertScheduler.dailySummaryId)
    .toList();

void main() {
  test('#445 默认 09:00 排一条汇总，正文带「今天 N 条」', () async {
    final plugin = _RecordingPlugin();
    final today = DateTime.now();
    final scheduler = await LocalReminderAlertScheduler.create(
      _FakeRepository([
        _item('a', DateTime(today.year, today.month, today.day, 23)),
        _item('b', DateTime(today.year, today.month, today.day, 22)),
      ]),
      _FakePrefs(const TaskPreference()),
      plugin: plugin,
      requestPermissions: () async {},
      initialize: false,
    );
    addTearDown(scheduler.dispose);

    await scheduler.rescheduleAll();

    final summary = _summary(plugin);
    expect(summary, hasLength(1), reason: '应排一条汇总通知');
    expect(summary.single.$3, '今天有 2 条提醒');
  });

  test('#445 N=0 时不排汇总（不发「今天 0 条」噪音）', () async {
    final plugin = _RecordingPlugin();
    final scheduler = await LocalReminderAlertScheduler.create(
      _FakeRepository([]),
      _FakePrefs(const TaskPreference()),
      plugin: plugin,
      requestPermissions: () async {},
      initialize: false,
    );
    addTearDown(scheduler.dispose);

    await scheduler.rescheduleAll();

    expect(_summary(plugin), isEmpty);
  });

  test('#445 时点改成 18:30 → 旧汇总撤销、按新时刻重排', () async {
    final plugin = _RecordingPlugin();
    final today = DateTime.now();
    final prefs = _FakePrefs(const TaskPreference());
    final scheduler = await LocalReminderAlertScheduler.create(
      _FakeRepository([
        _item('a', DateTime(today.year, today.month, today.day, 23)),
      ]),
      prefs,
      plugin: plugin,
      requestPermissions: () async {},
      initialize: false,
    );
    addTearDown(scheduler.dispose);

    await scheduler.rescheduleAll();
    expect(_summary(plugin), hasLength(1));

    prefs.pref = prefs.pref.copyWith(todayNotifyTime: '18:30');
    await scheduler.rescheduleAll();

    expect(_summary(plugin), hasLength(2), reason: '新时刻应再排一条');
    expect(plugin.cancelled, contains(LocalReminderAlertScheduler.dailySummaryId),
        reason: '旧的那条必须撤销');
    expect(_summary(plugin).last.$3, contains('今天有 1 条'));
  });

  test('#445 非法时点回落到 09:00（设置坏掉不能让通知消失）', () {
    const pref = TaskPreference(todayNotifyTime: 'nope');
    expect(pref.todayNotifyHourMinute, (9, 0));
    const bad = TaskPreference(todayNotifyTime: '25:99');
    expect(bad.todayNotifyHourMinute, (9, 0));
    const ok = TaskPreference(todayNotifyTime: '18:30');
    expect(ok.todayNotifyHourMinute, (18, 30));
  });
}
