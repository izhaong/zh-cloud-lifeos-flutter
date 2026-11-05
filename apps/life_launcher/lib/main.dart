import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:dio/dio.dart';
import 'package:feature_calendar/feature_calendar.dart' hide clockProvider;
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
import 'notifications/local_reminder_alert_scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'shell/pinned_tabs_service.dart';
import 'task_sync_wiring.dart';
import 'package:feature_note_cloud/feature_note_cloud.dart'
    show NoteRestSyncPort, NoteSyncCoordinator;

import 'note_sync_wiring.dart';
import 'app_locale.dart';
import 'settings_window/task_settings_window.dart';
import 'settings_window/task_settings_window_host.dart';
import 'shell/life_menu_bar.dart';
import 'shell/task_badge.dart';
import 'shell_providers.dart';

export 'app_locale.dart' show kAppLocale, kAppSupportedLocales;

/// 启动预热步骤兜底（#230）：这些步骤只做「尽力补齐」，失败不得阻断启动。
///
/// 修复前 `await refreshSubscribedHolidays(...)` 裸写在 `runApp` 之前：只要它
/// 抛（订阅过节假日的持久库端必抛只读日历），`runApp` 永远不执行，窗口纯黑
/// 且用户无法在界面内自救。数据库打开等**致命**步骤仍保持裸写、照常失败。
Future<void> runNonFatalStartupStep(
  String label,
  Future<void> Function() step,
) async {
  try {
    await step();
  } catch (e, st) {
    debugPrint('启动预热失败（$label）：$e');
    debugPrintStack(stackTrace: st);
  }
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // #577：设置辅助窗口是第二个 Flutter engine，会用同一 entrypoint 再跑一次
  // main；这里只起那一份最小 App，不初始化数据库/通知/同步（否则会多出
  // 一整套后台能力，且两个 engine 抢同一份本地库）。
  if (isTaskSettingsWindow(args)) {
    await runTaskSettingsWindow(args);
    return;
  }
  // parity#193：kalender 的星期/日期名走 intl，必须先装载本地化数据，
  // 否则 zh_CN 下日/周视图列头仍显示 Mon…Sun。
  await ensureCalendarDateLocalization();

  /// 组合根：单点工厂切换 InMemory / Drift；偏好存储与徽标源同在此注入。
  /// M4（flutter#4）：cloud 侧 AuthPort/SyncPort 真实现注入——
  /// 未登录时 currentSession=null，本地能力不受影响（离线优先红线）。
  final db = await openDefaultDatabase();
  final repository = DriftReminderRepository(db);
  // #448：手动时区。偏好流一变就更新「有效当下」的注入点——
  // 仓储（smart.today / 逾期判定）与 clockProvider（展示/分组）用的是同一个 now，
  // 否则会出现「侧栏说 3 条、列表里 2 条」的自相矛盾。
  String? manualTimeZone;
  repository.nowProvider = () => effectiveNow(DateTime.now(), manualTimeZone);
  final calendarRepository = openDefaultDriftCalendarRepository(db);
  // TC-UI-120（flutter#124 卡 4）：设置弹层四档落 Drift，重启后读回同一行
  final taskPreferenceRepository = DriftTaskPreferenceRepository(db);
  // #394（TC-NOTE-UI-111）：记录设置同样落 Drift——此前 NoteSettings 只活在
  // 内存里，重启就回默认值。
  final notePreferenceRepository = DriftNotePreferenceRepository(db);
  // F-03 / #280：记录仓库接回 Drift（此前长期是 InMemory，重启即丢全部笔录）
  final noteRepository = DriftNoteRepository(db);
  // parity#156：首启/空库兜底一条默认日历，避免「没有可用日历，无法保存」
  await ensureDefaultCalendar(calendarRepository);
  // parity#155：首启/空库兜底一个可写文件夹，避免「先新建一个文件夹」死路
  await ensureDefaultNoteFolder(noteRepository);
  // parity#182：已订阅节假日 → 按设备时区与当年补齐（UTC 墙钟会挪日/缺年）
  // #230：补齐失败（含只读日历写异常）只记日志，绝不阻断 runApp。
  await runNonFatalStartupStep(
    '订阅节假日补齐',
    () => refreshSubscribedHolidays(calendarRepository),
  );
  // #448：首次读取 + 持续跟踪手动时区（坏值由 effectiveNow 内部兜底）。
  taskPreferenceRepository.watchPreference().listen((preference) {
    manualTimeZone = preference.manualTimeZone;
  });
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
  final taskSyncOutbox = DriftSyncOutbox(db);
  final taskSyncCoordinator = TaskSyncCoordinator(
    outbox: taskSyncOutbox,
    syncPort: syncPort,
    applier: repository,
    cursors: DriftSyncCursorStore(db),
  );
  // #595（口径 1）：一轮成功后盖「上次同步」时间戳，供设置弹层显示；失败不盖。
  final taskSyncRound = TaskSyncRound(
    onPush: taskSyncCoordinator.push,
    onPull: taskSyncCoordinator.pull,
    onSyncOnce: taskSyncCoordinator.syncOnce,
    prefs: prefs,
    clock: DateTime.now,
  );
  // F-11：真实本地通知调度（开源包只声明接口）
  // #260：两个调度器共用**同一个**插件实例，避免第二次 initialize 覆盖掉
  // 日历那份带 categories/点击回调的配置。
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  final calendarAlertScheduler = await LocalCalendarAlertScheduler.create(
    calendarRepository,
    plugin: notificationsPlugin,
  );
  // #260：提醒事项到点提醒（Apple 对等；此前任务侧完全没有通知）
  final reminderAlertScheduler = await LocalReminderAlertScheduler.create(
    repository,
    taskPreferenceRepository,
    plugin: notificationsPlugin,
    initialize: false,
  );
  await reminderAlertScheduler.start();
  // F-17：日历云侧（同步 / 收件箱 / 导入导出），与任务共用同一会话存储
  // #416：记录域同步（#413 发件箱 → #414 applier → #415 协调器 → 这里接线）。
  final noteSyncPort = NoteRestSyncPort(
    http: DioNoteSyncHttp(dio: dio, store: sessionStore),
  );
  final noteSyncCoordinator = NoteSyncCoordinator(
    outbox: DriftSyncOutbox(db),
    applier: noteRepository as SyncApplier,
    cursors: DriftSyncCursorStore(db, domain: 'note'),
    port: noteSyncPort,
  );
  final calendarSyncPort = RestCalendarSyncPort(dio: dio, store: sessionStore);
  final calendarCollabPort = RestCalendarCollabPort(
    dio: dio,
    store: sessionStore,
  );
  // flutter#570：清单共享端口（写侧六端点 + 手机号解析 + 我参与的清单）。
  final taskCollabPort = RestTaskCollabPort(dio: dio, store: sessionStore);
  final calendarSyncCoordinator = CalendarSyncCoordinator(
    repository: calendarRepository,
    port: calendarSyncPort,
    store: sessionStore,
    deviceId: 'lifeos-launcher',
  );
  // 启动后静默补拉（未登录内部跳过；失败不挡本地）
  Future<void>(() async {
    try {
      await _syncCalendarsThenRefreshShares(
        coordinator: calendarSyncCoordinator,
        collabPort: calendarCollabPort,
        repository: calendarRepository,
      );
    } catch (_) {
      // 离线优先：启动同步失败不影响本地可用
    }
  });
  // #416：记录域冷启动补一轮（未登录零请求；失败不挡本地）
  Future<void>(() async {
    try {
      await syncNotesOnce(
        coordinator: noteSyncCoordinator,
        port: noteSyncPort,
        store: sessionStore,
        clock: DateTime.now,
      );
    } catch (_) {
      // 离线优先：未登录/断网都不挡本地能力
    }
  });
  // TC-SYNC-106/107：任务域冷启动也补一轮（先推本地、再拉增量落库）
  Future<void>(() async {
    try {
      await taskSyncRound.runOnce();
    } catch (_) {
      // 离线优先：未登录/断网都不挡本地能力
    }
  });

  // #368/#375：菜单命令出口。建在这里（main 作用域）是因为 ProviderScope 的
  // override 与 `LifeLauncherApp` 的菜单栏都要用它。
  final menuCommands = ValueNotifier<LifeMenuAction?>(null);
  // #575：「显示 → 前往」——清单快照由 feature_task 发布，点击经 request 回到页面。
  final menuGoToLists = ValueNotifier<List<LifeMenuGoToTarget>>(const []);
  final menuGoToRequest = ValueNotifier<String?>(null);
  runApp(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
        // #448：展示/分组用的「现在」与仓储同一个口径（手动时区生效后一起变）。
        // 两个包各有一个 `clockProvider`（日历/任务），此处按前缀只覆盖任务侧。
        clockProvider.overrideWith(
          (ref) =>
              () => effectiveNow(DateTime.now(), manualTimeZone),
        ),
        // #447：生产徽标此前恒为 {}（只有测试注入过假值）→ 这里派生真实数字。
        shellBadgeCountsProvider.overrideWith(
          (ref) => ref.watch(taskBadgeCountsProvider),
        ),
        taskPreferenceRepositoryProvider.overrideWithValue(
          taskPreferenceRepository,
        ),
        notePreferenceRepositoryProvider.overrideWithValue(
          notePreferenceRepository,
        ),
        calendarRepositoryProvider.overrideWithValue(calendarRepository),
        noteRepositoryProvider.overrideWithValue(noteRepository),
        calendarReminderRepositoryProvider.overrideWithValue(repository),
        calendarAlertSchedulerProvider.overrideWithValue(
          calendarAlertScheduler,
        ),
        reminderAlertSchedulerProvider.overrideWithValue(
          reminderAlertScheduler,
        ),
        calendarCollabPortProvider.overrideWithValue(calendarCollabPort),
        taskCollabPortProvider.overrideWithValue(taskCollabPort),
        lifeMenuCommandsProvider.overrideWithValue(menuCommands),
        lifeMenuGoToListsProvider.overrideWithValue(menuGoToLists),
        lifeMenuGoToRequestProvider.overrideWithValue(menuGoToRequest),
        calendarSyncCoordinatorProvider.overrideWithValue(
          calendarSyncCoordinator,
        ),
        calendarSyncTriggerProvider.overrideWith(
          (ref) => () async {
            await _syncCalendarsThenRefreshShares(
              coordinator: calendarSyncCoordinator,
              collabPort: calendarCollabPort,
              repository: calendarRepository,
            );
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
        // #254：日历侧栏显隐（☰）声明持久化到 shared_preferences，但组合根一直
        // 没注入——`SidebarVisibleNotifier` 读到 null 就永远回落「显示」且静默不写。
        sidebarPrefsProvider.overrideWithValue(prefs),
        // #256：任务区本地视图记忆（按列表「显示已完成」）也走同一份 prefs
        taskViewPrefsProvider.overrideWithValue(prefs),
        // #577：macOS 用独立辅助窗口承载设置；其它平台或建窗失败回退应用内页面。
        taskSettingsWindowOpenerProvider.overrideWith(
          (ref) => openTaskSettingsWindow,
        ),
        authPortProvider.overrideWithValue(authPort),
        syncPortProvider.overrideWithValue(taskSyncRound),
        // #595：同步状态只在设置弹层可见（待发条数 + 上次成功同步时刻）。
        syncStatusProvider.overrideWith(
          (ref) => readTaskSyncStatus(
            auth: authPort,
            outbox: taskSyncOutbox,
            prefs: prefs,
          ),
        ),
      ],
      child: TaskSettingsWindowHost(
        child: LifeLauncherApp(
          menuCommands: menuCommands,
          noteSyncCoordinator: noteSyncCoordinator,
          noteSyncPort: noteSyncPort,
          sessionStore: sessionStore,
        ),
      ),
    ),
  );
}

/// #577：打开设置界面——macOS 优先独立辅助窗口，失败回退应用内页面。
///
/// 已存在的设置窗口只激活不新建（用户点「完成」走原生 close，窗口会被销毁，
/// 下次仍是新窗口；退回 hide 的平台则复用同一窗口）。
Future<void> openTaskSettingsWindow(
  BuildContext context, {
  VoidCallback? onOpenCloudLogin,
}) async {
  taskSettingsCloudLogin.value = onOpenCloudLogin;
  Future<void> openInApp() => showTaskSettingsSheet(
    context,
    onOpenCloudLogin: onOpenCloudLogin == null
        ? null
        : (_) => onOpenCloudLogin(),
  );
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
    return openInApp();
  }
  try {
    final existing = (await WindowController.getAll()).where(
      (c) => c.arguments == kTaskSettingsWindowArgument,
    );
    if (existing.isNotEmpty) {
      await WindowController.fromWindowId(existing.first.windowId).show();
      return;
    }
    final controller = await WindowController.create(
      const WindowConfiguration(
        arguments: kTaskSettingsWindowArgument,
        hiddenAtLaunch: true,
      ),
    );
    await controller.show();
  } catch (error) {
    debugPrint('设置窗口打开失败，回退应用内页面：$error');
    if (!context.mounted) return;
    await openInApp();
  }
}

class LifeLauncherApp extends ConsumerStatefulWidget {
  const LifeLauncherApp({
    super.key,
    this.menuCommands,
    this.noteSyncCoordinator,
    this.noteSyncPort,
    this.sessionStore,
  });

  /// 菜单命令出口（#368/#375）——在 `main()` 里建，同时注入 ProviderScope 与菜单栏。
  ///
  /// 可空：widget 测试/非 macOS 没有菜单栏，此时不建总线（页面侧订阅会拿到 null）。
  final ValueNotifier<LifeMenuAction?>? menuCommands;

  /// 记录域同步链（#416）：回前台时续一轮。可空——widget 测试与未登录场景不注入。
  final NoteSyncCoordinator? noteSyncCoordinator;
  final NoteRestSyncPort? noteSyncPort;
  final SessionStore? sessionStore;

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
    final notePort = widget.noteSyncPort;
    final noteCoordinator = widget.noteSyncCoordinator;
    final store = widget.sessionStore;
    Future<void>(() async {
      try {
        await port.push();
        await port.pull();
      } catch (_) {
        // 离线优先：续推失败不影响本地可用
      }
      if (notePort != null && noteCoordinator != null && store != null) {
        try {
          await syncNotesOnce(
            coordinator: noteCoordinator,
            port: notePort,
            store: store,
            clock: DateTime.now,
          );
        } catch (_) {
          // 记录域同理：失败不打扰用户
        }
      }
    });
  }

  /// 系统亮/暗切换要重建主题：令牌是 Apple 动态色，Material 岛的静态
  /// `ColorScheme` 也要按当前档位重新解算。
  @override
  void didChangePlatformBrightness() => setState(() {});

  /// 提高对比度变化也要重建（#348）。
  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final router = buildLifeRouter(ref);
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final brightness = dispatcher.platformBrightness;
    // Apple「提高对比度」：辅助功能开关，色值要切到高对比档（#348）。
    final highContrast = dispatcher.accessibilityFeatures.highContrast;
    // Apple「粗体文本」：同一组辅助功能开关，主题层提字重（#353）。
    final boldText = dispatcher.accessibilityFeatures.boldText;
    final app = CupertinoApp.router(
      title: 'LifeOS 生活台',
      debugShowCheckedModeBanner: false,
      theme: LifeTokens.cupertino(brightness, highContrast, boldText),
      // 产品裁定（#387）：LifeOS **只做中文 UI**。
      //
      // 此前 `supportedLocales` 里摆着 `en_US`、`locale` 又写死 `zh_CN`：
      // 声明支持英文却在运行时不可达，是**假能力**，也让 TC-REG-104
      //（「切英文无中文残留」）成为结构上做不到的用例。
      //
      // 现在只声明 zh_CN——app 自身文案是硬编码中文（142/142 个 UI 文件、
      // 652 行字面量），全量 i18n 是另一个量级的事，需要时单独立项（含 ARB 抽取）。
      // 随之保证的仍是：**框架文案**（日期/星期/无障碍读数）随 zh_CN 正确渲染。
      locale: kAppLocale,
      supportedLocales: kAppSupportedLocales,
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      routerConfig: router,
      // #195：给未被主题覆盖的文本也挂上 CJK 回退（Web 端不读系统字体）
      builder: (context, child) => DefaultTextStyle.merge(
        style: const TextStyle(fontFamilyFallback: LifeTokens.cjkFontFallback),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    // #368：macOS 菜单栏整体接管（引擎默认项是英文且没有「文件」菜单）。
    // 只在 macOS 包一层——这是平台能力差异，不是按平台分叉页面树。
    //
    // 用 `defaultTargetPlatform` 而不是 `dart:io Platform.isMacOS`：
    // 后者在 widget 测试里返回**宿主**平台（macOS），而框架的 target 是 android，
    // 于是 PlatformProvidedMenuItem 序列化时抛「Platform android has no … menu」。
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
      return app;
    }
    final commands = widget.menuCommands;
    if (commands == null) {
      return app;
    }
    return LifeMenuBar(
      commands: commands,
      goToLists: ProviderScope.containerOf(context, listen: false)
          .read(lifeMenuGoToListsProvider),
      goToRequests: ProviderScope.containerOf(context, listen: false)
          .read(lifeMenuGoToRequestProvider),
      child: app,
    );
  }
}

/// 跑一轮日历同步；若本轮 pull 里出现**共享关系变更**，再拉一次日历列表（#369）。
///
/// 服务端在共享邀请/回复/改权限/移除时会建/删**影子日历**（同一事务），而 pull 的
/// cursor 已经推进——所以不能指望下一轮增量把影子日历带回来，必须用 REST 列表补一次。
/// 失败不向上抛：调用方（启动/手动触发）都按「离线优先」处理。
Future<void> _syncCalendarsThenRefreshShares({
  required CalendarSyncCoordinator coordinator,
  required CalendarCollabPort collabPort,
  required CalendarRepository repository,
}) async {
  final report = await coordinator.syncOnce();
  if (!report.shareChanged) {
    return;
  }
  try {
    await refreshCalendarsFromRest(port: collabPort, repository: repository);
  } catch (_) {
    // 影子日历没补上不影响本地可用；下一轮 pull 或手动刷新会再补
  }
}
