import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 真实本地通知调度（F-11；仅壳 `life_launcher` 依赖插件）。
///
/// feature_calendar 只声明 [CalendarAlertScheduler]；本实现由组合根注入。
class LocalCalendarAlertScheduler implements CalendarAlertScheduler {
  LocalCalendarAlertScheduler._(this._plugin, this._repository);

  static const String channelId = 'lifeos_calendar_alerts';
  static const String _categoryId = 'lifeos_calendar_alert';
  static const int _maxSlots = 20;

  final FlutterLocalNotificationsPlugin _plugin;
  final CalendarRepository _repository;
  final Map<String, CalendarEvent> _events = {};

  static Future<LocalCalendarAlertScheduler> create(
      CalendarRepository repository) async {
    tzdata.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    final scheduler = LocalCalendarAlertScheduler._(plugin, repository);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(_categoryId, actions: [
          DarwinNotificationAction.plain('snooze', '稍后 9 分钟'),
          DarwinNotificationAction.plain('dismiss', '关闭',
              options: {DarwinNotificationActionOption.foreground}),
        ]),
      ],
    );
    await plugin.initialize(
      settings: InitializationSettings(android: android, iOS: darwin, macOS: darwin),
      onDidReceiveNotificationResponse: scheduler._onResponse,
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return scheduler;
  }

  @override
  Future<void> scheduleEvent(CalendarEvent event) async {
    await cancelEvent(event.id);
    _events[event.id] = event;
    final triggers =
        calendarAlertTriggers(event, after: DateTime.now().toUtc());
    for (var i = 0; i < triggers.length && i < _maxSlots; i++) {
      await _schedule(event, _eventNotificationId(event.id, i), triggers[i]);
    }
  }

  @override
  Future<void> cancelEvent(String eventId) async {
    for (var i = 0; i < _maxSlots; i++) {
      await _plugin.cancel(id: _eventNotificationId(eventId, i));
    }
    await _plugin.cancel(id: _eventNotificationId(eventId, _maxSlots));
  }

  @override
  Future<void> snooze(CalendarEvent event, DateTime fireAt) async {
    _events[event.id] = event;
    await _schedule(event, _eventNotificationId(event.id, _maxSlots),
        fireAt.toUtc());
  }

  Future<void> _schedule(
      CalendarEvent event, int id, DateTime fireAtUtc) async {
    final title = event.title.trim().isEmpty ? '日程提醒' : event.title;
    final when = tz.TZDateTime.from(fireAtUtc.toUtc(), tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: _body(event),
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          '日程提醒',
          channelDescription: 'LifeOS 日程提醒',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('snooze', '稍后 9 分钟'),
            AndroidNotificationAction('dismiss', '关闭',
                showsUserInterface: false),
          ],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: _categoryId),
        macOS: DarwinNotificationDetails(categoryIdentifier: _categoryId),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: event.id,
    );
  }

  Future<void> _onResponse(NotificationResponse response) async {
    final eventId = response.payload;
    if (eventId == null) {
      return;
    }
    if (response.actionId == 'snooze') {
      final event = _events[eventId] ?? await _repository.getEvent(eventId);
      if (event != null) {
        await CalendarNotificationActions(this)
            .onSnooze(event);
      }
    }
  }

  String _body(CalendarEvent event) {
    if (event.location == null || event.location!.isEmpty) {
      return '日程提醒';
    }
    return event.location!;
  }

  static int _eventNotificationId(String eventId, int slot) {
    final base = eventId.hashCode & 0x0FFFFFFF;
    return (base * 32 + slot) & 0x7FFFFFFF;
  }
}
