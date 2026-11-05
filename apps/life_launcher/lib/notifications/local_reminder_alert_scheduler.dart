import 'dart:async';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../shell/task_badge.dart' show taskBadgeCount;

/// 任务提醒的真实本地通知调度（Apple：提醒到点弹通知）。
///
/// 与 `LocalCalendarAlertScheduler` 同一套路：插件只在壳层依赖，feature_task
/// 只声明 [ReminderAlertScheduler]。仓库流一变（新建/改期/完成/删除）就整表
/// 收敛，不做增量 diff——提醒条数有限，收敛比补丁可靠。
class LocalReminderAlertScheduler implements ReminderAlertScheduler {
  LocalReminderAlertScheduler._(
    this._plugin,
    this._repository,
    this._preferences, {
    this._requestPermissions,
    this.maxSlots = 64,
  });

  static const String channelId = 'lifeos_task_alerts';

  final FlutterLocalNotificationsPlugin _plugin;
  final ReminderRepository _repository;
  final TaskPreferenceRepository _preferences;
  final Future<void> Function()? _requestPermissions;

  /// 同时最多排多少条（防一次性排几百条）。
  final int maxSlots;

  /// itemId → (通知 id, 触发时刻, 标题)：用来判断哪些要新增/撤销/重排。
  final Map<String, (int, DateTime, String)> _scheduled = {};
  StreamSubscription<List<ReminderItem>>? _sub;
  StreamSubscription<TaskPreference>? _prefsSub;
  bool _permissionsRequested = false;
  bool _rescheduling = false;
  bool _again = false;

  static Future<LocalReminderAlertScheduler> create(
    ReminderRepository repository,
    TaskPreferenceRepository preferences, {
    FlutterLocalNotificationsPlugin? plugin,
    Future<void> Function()? requestPermissions,
    int maxSlots = 64,
    bool initialize = true,
  }) async {
    tzdata.initializeTimeZones();
    final plugin0 = plugin ?? FlutterLocalNotificationsPlugin();
    final scheduler = LocalReminderAlertScheduler._(
      plugin0,
      repository,
      preferences,
      requestPermissions:
          requestPermissions ??
          () async {
            final ios = plugin0
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >();
            if (ios != null) {
              await ios.requestPermissions(
                alert: true,
                badge: false,
                sound: true,
              );
              return;
            }
            final mac = plugin0
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >();
            if (mac != null) {
              await mac.requestPermissions(
                alert: true,
                badge: false,
                sound: true,
              );
              return;
            }
            await plugin0
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission();
          },
      maxSlots: maxSlots,
    );

    // 审查 R1：与日历共用同一个插件实例时**不要**再 initialize——那会用一份
    // 不带 categories/onDidReceiveNotificationResponse 的配置覆盖掉日历的点击
    // 与「稍后 9 分钟」回调。共用实例的初始化由日历侧完成。
    if (initialize) {
      await plugin0.initialize(
        settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: null,
      );
    }
    return scheduler;
  }

  /// 订阅仓库：首次立即收敛，之后每次变更再收敛（串行化，避免并发排重）。
  Future<void> start() async {
    await _sub?.cancel();
    _sub = _repository
        .watchItems(includeCompleted: true)
        .listen((_) => unawaited(rescheduleAll()));
    // 审查 R1：「全天提醒时点」开关一变也要立刻收敛，否则已排/该撤的不动
    _prefsSub?.cancel();
    _prefsSub = _preferences.watchPreference().listen(
      (_) => unawaited(rescheduleAll()),
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _prefsSub?.cancel();
    _sub = null;
    _prefsSub = null;
  }

  @override
  Future<void> rescheduleAll() async {
    if (_rescheduling) {
      _again = true;
      return;
    }
    _rescheduling = true;
    try {
      do {
        _again = false;
        await _reconcile();
      } while (_again);
    } finally {
      _rescheduling = false;
    }
  }

  @override
  Future<void> cancelAll() async {
    for (final entry in _scheduled.entries) {
      await _plugin.cancel(id: entry.value.$1);
    }
    _scheduled.clear();
    if (_summaryScheduledAt != null) {
      await _plugin.cancel(id: dailySummaryId);
      _summaryScheduledAt = null;
    }
  }

  Future<void> _reconcile() async {
    final items = await _repository
        .watchItems(includeCompleted: true)
        .first;
    final prefs = await _preferences.watchPreference().first;
    final now = DateTime.now();
    // 正文用标题：改标题也要跟着变（同一轮里刷新）
    for (final item in items) {
      _titles[item.id] = item.title.isEmpty ? '待办到点' : item.title;
    }

    final want = <String, DateTime>{};
    for (final item in items) {
      final fireAt = reminderFireAt(item, allDayNotify: prefs.allDayNotify);
      if (fireAt == null || !fireAt.isAfter(now)) continue;
      want[item.id] = fireAt;
    }
    final ordered = want.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final capped = ordered.take(maxSlots).toList();

    // 撤销：已排但不再需要（完成/删除/改到过去/超出上限）
    final keep = {for (final e in capped) e.key: e.value};
    for (final itemId in _scheduled.keys.toList()) {
      if (!keep.containsKey(itemId)) {
        await _plugin.cancel(id: _scheduled[itemId]!.$1);
        _scheduled.remove(itemId);
      }
    }

    await _reconcileDailySummary(items, prefs, now);

    for (final entry in capped) {
      final itemId = entry.key;
      final fireAt = entry.value;
      final title = _titles[itemId] ?? '待办到点';
      final current = _scheduled[itemId];
      if (current != null && current.$2 == fireAt && current.$3 == title) {
        continue; // 时刻与标题都没变
      }
      if (current != null) await _plugin.cancel(id: current.$1);
      final id = _notificationId(itemId);
      await _ensurePermissionsRequested();
      await _schedule(itemId, id, fireAt, title);
      _scheduled[itemId] = (id, fireAt, title);
    }
  }

  Future<void> _ensurePermissionsRequested() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;
    await _requestPermissions?.call();
  }

  Future<void> _schedule(
    String itemId,
    int id,
    DateTime fireAt,
    String body,
  ) async {
    await _plugin.zonedSchedule(
      id: id,
      title: '提醒事项',
      body: body,
      scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          '任务提醒',
          channelDescription: 'LifeOS 提醒事项到点提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: itemId,
    );
  }

  final Map<String, String> _titles = {};

  static int _notificationId(String itemId) =>
      ('task::$itemId').hashCode & 0x7FFFFFFF;

  /// 「今天」汇总通知的固定 id（每条提醒各有 id，这条单独一个）。
  static const int dailySummaryId = 0x7A11;

  /// 当前已排的汇总通知触发时刻（null = 没排）。
  DateTime? _summaryScheduledAt;

  /// 排「今天」汇总（#445）。
  ///
  /// 口径：每天在设置时点发一条「今天有 N 条提醒」；
  /// - **N=0 不排**（不发「今天 0 条」的噪音），并撤掉旧的；
  /// - 时点改了要重排（旧的那条撤掉）；
  /// - 今天该时点已过 → 从明天开始（不补发）。
  Future<void> _reconcileDailySummary(
    List<ReminderItem> items,
    TaskPreference prefs,
    DateTime now,
  ) async {
    final (hour, minute) = prefs.todayNotifyHourMinute;
    var fireAt = DateTime(now.year, now.month, now.day, hour, minute);
    if (!fireAt.isAfter(now)) {
      fireAt = fireAt.add(const Duration(days: 1));
    }
    final count = taskBadgeCount(items, now: now, includeTodayDue: true);
    if (count == 0) {
      if (_summaryScheduledAt != null) {
        await _plugin.cancel(id: dailySummaryId);
        _summaryScheduledAt = null;
      }
      return;
    }
    if (_summaryScheduledAt == fireAt) return; // 时刻没变
    if (_summaryScheduledAt != null) {
      await _plugin.cancel(id: dailySummaryId);
    }
    await _ensurePermissionsRequested();
    await _plugin.zonedSchedule(
      id: dailySummaryId,
      title: '提醒事项',
      body: '今天有 $count 条提醒',
      scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          '任务提醒',
          channelDescription: 'LifeOS 提醒事项到点提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'daily-summary',
    );
    _summaryScheduledAt = fireAt;
  }
}
