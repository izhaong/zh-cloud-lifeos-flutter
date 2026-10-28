import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:dio/dio.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_calendar_cloud/feature_calendar_cloud.dart';
import 'package:feature_note/feature_note.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_task/feature_task.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';
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
  // parity#193：kalender 的星期/日期名走 intl，必须先装载本地化数据，
  // 否则 zh_CN 下日/周视图列头仍显示 Mon…Sun。
  await ensureCalendarDateLocalization();

  /// 组合根：单点工厂切换 InMemory / Drift；偏好存储与徽标源同在此注入。
  /// M4（flutter#4）：cloud 侧 AuthPort/SyncPort 真实现注入——
  /// 未登录时 currentSession=null，本地能力不受影响（离线优先红线）。
  final db = await openDefaultDatabase();
  final repository = DriftReminderRepository(db);
  final calendarRepository = openDefaultDriftCalendarRepository(db);
  // TC-UI-120（flutter#124 卡 4）：设置弹层四档落 Drift，重启后读回同一行
  final taskPreferenceRepository = DriftTaskPreferenceRepository(db);
  // F-03：记录仓库（Drift 实现随 F-04 落地前先 InMemory；组合根单点切换）
  final noteRepository = InMemoryNoteRepository();
  // parity#156：首启/空库兜底一条默认日历，避免「没有可用日历，无法保存」
  await ensureDefaultCalendar(calendarRepository);
  // parity#155：首启/空库兜底一个可写文件夹，避免「先新建一个文件夹」死路
  await ensureDefaultNoteFolder(noteRepository);
  // parity#182：已订阅节假日 → 按设备时区与当年补齐（UTC 墙钟会挪日/缺年）
  await refreshSubscribedHolidays(calendarRepository);
  final prefs = await SharedPreferences.getInstance();
  final dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'LIFEOS_API_BASE',
        defaultValue: 'https://lifeos.zh04.com',
      ),
    ),
  );
  final sessionStore = SecureSessionStore();
  final authPort = RestAuthPort(dio: dio, store: sessionStore);
  // TC-SYNC-114：401 时先走 authPort.refresh() 换新 token 再重试，不再拿过期 token 空转
  final syncPort = RestSyncPort(
    dio: dio,
    store: sessionStore,
    refreshSession: () async => await authPort.refresh() != null,
  );
  // 卡 2（flutter#124）：注入壳层的 SyncPort 是协调器——push() 从 Drift 发件箱
  // 真装载变更，回执带 serverId 时同事务回填 reminder_items.remote_id；
  // 卡 3：pull() 带上次游标拉增量，交仓库落 Drift（delete 进回收窗）后才前进游标。
  final taskSyncCoordinator = TaskSyncCoordinator(
    outbox: DriftSyncOutbox(db),
    syncPort: syncPort,
    applier: repository,
    cursors: DriftSyncCursorStore(db),
  );
  // F-11：真实本地通知调度（开源包只声明接口）
  final calendarAlertScheduler = await LocalCalendarAlertScheduler.create(
    calendarRepository,
  );
  // F-17：日历云侧（同步 / 收件箱 / 导入导出），与任务共用同一会话存储
  final calendarSyncPort = RestCalendarSyncPort(dio: dio, store: sessionStore);
  final calendarCollabPort = RestCalendarCollabPort(
    dio: dio,
    store: sessionStore,
  );
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
  // TC-SYNC-106/107：任务域冷启动也补一轮（先推本地、再拉增量落库）
  Future<void>(() async {
    try {
      await taskSyncCoordinator.syncOnce();
    } catch (_) {
      // 离线优先：未登录/断网都不挡本地能力
    }
  });

  runApp(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
        taskPreferenceRepositoryProvider.overrideWithValue(
          taskPreferenceRepository,
        ),
        calendarRepositoryProvider.overrideWithValue(calendarRepository),
        noteRepositoryProvider.overrideWithValue(noteRepository),
        calendarReminderRepositoryProvider.overrideWithValue(repository),
        calendarAlertSchedulerProvider.overrideWithValue(
          calendarAlertScheduler,
        ),
        calendarCollabPortProvider.overrideWithValue(calendarCollabPort),
        calendarSyncCoordinatorProvider.overrideWithValue(
          calendarSyncCoordinator,
        ),
        calendarSyncTriggerProvider.overrideWith(
          (ref) => () async {
            await calendarSyncCoordinator.syncOnce();
          },
        ),
        calendarInboxOpenerProvider.overrideWith(
          (ref) =>
              (context) => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) =>
                      const LifeMaterialIsland(child: CalendarCloudPage()),
                ),
              ),
        ),
        pinnedTabsServiceProvider.overrideWithValue(PinnedTabsService(prefs)),
        authPortProvider.overrideWithValue(authPort),
        syncPortProvider.overrideWithValue(taskSyncCoordinator),
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
    // 回前台续一轮（TC-SYNC-107「离线改 → 联网推」的触发点）：
    // 未登录/队空内部直接返回，失败不清队也不打扰用户。
    final port = ref.read(syncPortProvider);
    Future<void>(() async {
      try {
        await port.push();
        await port.pull();
      } catch (_) {
        // 离线优先：续推失败不影响本地可用
      }
    });
  }

  /// 系统亮/暗切换要重建主题：令牌是 Apple 动态色，Material 岛的静态
  /// `ColorScheme` 也要按当前档位重新解算。
  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final router = buildLifeRouter(ref);
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return CupertinoApp.router(
      title: 'LifeOS 生活台',
      debugShowCheckedModeBanner: false,
      theme: LifeTokens.cupertino(brightness),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      routerConfig: router,
      // #195：给未被主题覆盖的文本也挂上 CJK 回退（Web 端不读系统字体）
      builder: (context, child) => DefaultTextStyle.merge(
        style: const TextStyle(
          fontFamilyFallback: LifeTokens.cjkFontFallback,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
