import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/notifications/local_calendar_alert_scheduler.dart';

class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  int zonedScheduleCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #zonedSchedule) {
      zonedScheduleCalls++;
    }
    return Future<bool?>.value(true);
  }
}

class _FakeRepository implements CalendarRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

CalendarEvent _event() => CalendarEvent(
  id: 'evt-1',
  calendarId: 'cal-1',
  uid: 'uid-1',
  title: '周会',
  startAt: DateTime.utc(2026, 10, 28, 9),
  endAt: DateTime.utc(2026, 10, 28, 10),
  timeZone: 'UTC',
  alerts: const [EventAlert(offsetMinutes: 0)],
  updatedAt: DateTime.utc(2026, 10, 27),
);

void main() {
  test('create 不请求通知权限（首启零弹窗，#150）', () async {
    var permissionCalls = 0;
    await LocalCalendarAlertScheduler.create(
      _FakeRepository(),
      plugin: _RecordingPlugin(),
      requestPermissions: () async => permissionCalls++,
    );
    expect(permissionCalls, 0);
  });

  test('首次 snooze 才请求一次权限并排一条通知', () async {
    var permissionCalls = 0;
    final plugin = _RecordingPlugin();
    final scheduler = await LocalCalendarAlertScheduler.create(
      _FakeRepository(),
      plugin: plugin,
      requestPermissions: () async => permissionCalls++,
    );
    final event = _event();
    await scheduler.snooze(event, DateTime.utc(2026, 10, 28, 9, 5));
    expect(permissionCalls, 1);
    expect(plugin.zonedScheduleCalls, 1);
  });

  test('第二次 snooze 不重复请求权限', () async {
    var permissionCalls = 0;
    final plugin = _RecordingPlugin();
    final scheduler = await LocalCalendarAlertScheduler.create(
      _FakeRepository(),
      plugin: plugin,
      requestPermissions: () async => permissionCalls++,
    );
    final event = _event();
    await scheduler.snooze(event, DateTime.utc(2026, 10, 28, 9, 5));
    await scheduler.snooze(event, DateTime.utc(2026, 10, 28, 9, 10));
    expect(permissionCalls, 1);
    expect(plugin.zonedScheduleCalls, 2);
  });
}
