import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/notifications/local_reminder_alert_scheduler.dart';

/// #260：任务提醒到点通知的调度（真实实现，插件用假体记录）。
class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  final List<int> scheduled = [];
  final List<int> canceled = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #zonedSchedule) {
      scheduled.add(invocation.namedArguments[#id] as int);
      return Future<void>.value();
    }
    if (invocation.memberName == #initialize) {
      return Future<bool?>.value(true);
    }
    if (invocation.memberName == #cancel) {
      canceled.add(invocation.namedArguments[#id] as int);
      return Future<void>.value();
    }
    return Future<bool?>.value(true);
  }
}

class _FakeRepo implements ReminderRepository {
  _FakeRepo(this.items);
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
  _FakePrefs({this.allDayNotify = true});
  final bool allDayNotify;
  @override
  Stream<TaskPreference> watchPreference() =>
      Stream.value(TaskPreference(allDayNotify: allDayNotify));
  @override
  Future<void> savePreference(TaskPreference preference) async {}
}

ReminderItem item(String id, DateTime? dueAt, {bool completed = false}) =>
    ReminderItem(
      id: id,
      listId: 'list.a',
      title: id,
      dueAt: dueAt,
      isCompleted: completed,
    );

void main() {
  test('未来未完成的提醒各排一条；已完成/无时间/已过期不排', () async {
    final now = DateTime.now();
    final repo = _FakeRepo([
      item('a', now.add(const Duration(hours: 1))),
      item('b', now.add(const Duration(hours: 2)), completed: true),
      item('c', null),
      item('d', now.subtract(const Duration(hours: 1))),
    ]);
    final plugin = _RecordingPlugin();
    final scheduler = await LocalReminderAlertScheduler.create(
      repo,
      _FakePrefs(),
      plugin: plugin,
      requestPermissions: () async {},
    );

    await scheduler.rescheduleAll();

    expect(plugin.scheduled, hasLength(1), reason: '只有 a 该排');
  });

  test('完成一条后要撤销它那条通知', () async {
    final now = DateTime.now();
    final repo = _FakeRepo([
      item('a', now.add(const Duration(hours: 1))),
      item('b', now.add(const Duration(hours: 2))),
    ]);
    final plugin = _RecordingPlugin();
    final scheduler = await LocalReminderAlertScheduler.create(
      repo,
      _FakePrefs(),
      plugin: plugin,
      requestPermissions: () async {},
    );
    await scheduler.rescheduleAll();
    expect(plugin.scheduled, hasLength(2));

    repo.items = [
      item('a', now.add(const Duration(hours: 1))),
      item('b', now.add(const Duration(hours: 2)), completed: true),
    ];
    await scheduler.rescheduleAll();

    expect(plugin.canceled, isNotEmpty, reason: '完成的那条要撤');
  });

  test('「全天提醒时点」关闭 → 只有日期的提醒不排', () async {
    final now = DateTime.now();
    final repo = _FakeRepo([
      item('a', DateTime(now.year, now.month, now.day).add(const Duration(days: 1))),
    ]);
    final plugin = _RecordingPlugin();
    final scheduler = await LocalReminderAlertScheduler.create(
      repo,
      _FakePrefs(allDayNotify: false),
      plugin: plugin,
      requestPermissions: () async {},
    );
    await scheduler.rescheduleAll();
    expect(plugin.scheduled, isEmpty);
  });
}
