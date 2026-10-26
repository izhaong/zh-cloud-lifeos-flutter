import 'package:app_core/app_core.dart';
import 'package:dio/dio.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_calendar_cloud/feature_calendar_cloud.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_task/feature_task.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'router/life_router.dart';
import 'notifications/local_calendar_alert_scheduler.dart';
import 'shell/pinned_tabs_service.dart';
import 'shell_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 组合根：单点工厂切换 InMemory / Drift；偏好存储与徽标源同在此注入。
  /// M4（flutter#4）：cloud 侧 AuthPort/SyncPort 真实现注入——
  /// 未登录时 currentSession=null，本地能力不受影响（离线优先红线）。
  final db = await openDefaultDatabase();
  final repository = DriftReminderRepository(db);
  final calendarRepository = openDefaultDriftCalendarRepository(db);
  final prefs = await SharedPreferences.getInstance();
  final dio = Dio(BaseOptions(baseUrl: const String.fromEnvironment(
    'LIFEOS_API_BASE',
    defaultValue: 'https://lifeos.zh04.com',
  )));
  final sessionStore = SecureSessionStore();
  final authPort = RestAuthPort(dio: dio, store: sessionStore);
  final syncPort = RestSyncPort(dio: dio, store: sessionStore);
  // F-11：真实本地通知调度（开源包只声明接口）
  final calendarAlertScheduler =
      await LocalCalendarAlertScheduler.create(calendarRepository);
  // F-17：日历云侧（同步 / 收件箱 / 导入导出），与任务共用同一会话存储
  final calendarSyncPort =
      RestCalendarSyncPort(dio: dio, store: sessionStore);
  final calendarCollabPort =
      RestCalendarCollabPort(dio: dio, store: sessionStore);
  final calendarSyncCoordinator = CalendarSyncCoordinator(
    repository: calendarRepository,
    port: calendarSyncPort,
    store: sessionStore,
    deviceId: 'lifeos-launcher',
  );
  // 启动后静默补拉（未登录内部跳过；失败不挡本地）
  Future<void>(() async {
    try {
      await calendarSyncCoordinator.syncOnce();
    } catch (_) {
      // 离线优先：启动同步失败不影响本地可用
    }
  });

  runApp(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
        calendarRepositoryProvider.overrideWithValue(calendarRepository),
        calendarReminderRepositoryProvider.overrideWithValue(repository),
        calendarAlertSchedulerProvider.overrideWithValue(calendarAlertScheduler),
        calendarCollabPortProvider.overrideWithValue(calendarCollabPort),
        calendarSyncCoordinatorProvider
            .overrideWithValue(calendarSyncCoordinator),
        calendarSyncTriggerProvider.overrideWith((ref) => () async {
              await calendarSyncCoordinator.syncOnce();
            }),
        calendarInboxOpenerProvider.overrideWith(
          (ref) => (context) => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CalendarCloudPage()),
          ),
        ),
        pinnedTabsServiceProvider.overrideWithValue(
          PinnedTabsService(prefs),
        ),
        authPortProvider.overrideWithValue(authPort),
        syncPortProvider.overrideWithValue(syncPort),
      ],
      child: const LifeLauncherApp(),
    ),
  );
}

class LifeLauncherApp extends ConsumerWidget {
  const LifeLauncherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = buildLifeRouter(ref);
    return MaterialApp.router(
      title: 'LifeOS 生活台',
      debugShowCheckedModeBanner: false,
      theme: LifeTokens.light(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
