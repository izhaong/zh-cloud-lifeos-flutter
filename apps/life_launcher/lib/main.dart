import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:dio/dio.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_calendar_cloud/feature_calendar_cloud.dart';
import 'package:feature_note/feature_note.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_task/feature_task.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';
import 'package:flutter/material.dart' show ScaffoldMessenger, Theme;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalMaterialLocalizations, GlobalWidgetsLocalizations;
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
  // F-03：记录仓库（Drift 实现随 F-04 落地前先 InMemory；组合根单点切换）
  final noteRepository = InMemoryNoteRepository();
  final prefs = await SharedPreferences.getInstance();
  final dio = Dio(BaseOptions(baseUrl: const String.fromEnvironment(
    'LIFEOS_API_BASE',
    defaultValue: 'https://lifeos.zh04.com',
  )));
  final sessionStore = SecureSessionStore();
  final authPort = RestAuthPort(dio: dio, store: sessionStore);
  // TC-SYNC-114：401 时先走 authPort.refresh() 换新 token 再重试，不再拿过期 token 空转
  final syncPort = RestSyncPort(
    dio: dio,
    store: sessionStore,
    refreshSession: () async => await authPort.refresh() != null,
  );
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
        noteRepositoryProvider.overrideWithValue(noteRepository),
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
            CupertinoPageRoute<void>(
              builder: (_) => const LifeMaterialIsland(
                child: CalendarCloudPage(),
              ),
            ),
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

class LifeLauncherApp extends ConsumerStatefulWidget {
  const LifeLauncherApp({super.key});

  @override
  ConsumerState<LifeLauncherApp> createState() => _LifeLauncherAppState();
}

class _LifeLauncherAppState extends ConsumerState<LifeLauncherApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 跨日刷新（真实 bug）：app 长时间在后台/跨午夜后回到前台，
  /// 「今天/计划」等按本地日过滤的智能列表仍是昨天快照
  /// （表现为「今天」里躺着昨日项，分区头却已标「已过期」）。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.read(reminderRepositoryProvider).checkDayRollover();
  }

  @override
  Widget build(BuildContext context) {
    final router = buildLifeRouter(ref);
    return CupertinoApp.router(
      title: 'LifeOS 生活台',
      debugShowCheckedModeBanner: false,
      theme: LifeTokens.cupertino(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      builder: (context, child) => Theme(
        data: LifeTokens.materialIsland(),
        child: ScaffoldMessenger(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      routerConfig: router,
    );
  }
}
