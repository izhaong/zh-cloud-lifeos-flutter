// #577：设置独立辅助窗口（macOS）。
//
// desktop_multi_window 为第二窗口起一个独立 Flutter engine，并用同一 Dart
// entrypoint 再调一次 `main`，参数形如
// `["multi_window", <windowId>, "lifeos-task-settings"]`。组合根在 `main()`
// 最前面分流，第二窗口只跑这一份最小 App：不开数据库、不建通知/同步调度，
// 否则会凭空多出一套后台能力。
//
// 读写仍归主窗口：第二窗口经 unidirectional 通道 `getState/apply/reset`
// 取当前偏好并把改动写回，主窗口用同一份 Provider/仓储落库——偏好只有
// 一个真身，窗口只是另一个壳。
import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalMaterialLocalizations, GlobalWidgetsLocalizations;

import '../app_locale.dart';

/// 最近一次「设置窗口 → 云同步」入口，由主窗口打开设置时登记。
///
/// null = 当前入口没有登录页（菜单路径），设置窗口里那一行按「登录后可用」弱化。
final ValueNotifier<VoidCallback?> taskSettingsCloudLogin =
    ValueNotifier<VoidCallback?>(null);

/// 第二窗口的业务参数（与主窗口的空参数区分）。
const String kTaskSettingsWindowArgument = 'lifeos-task-settings';

/// 主窗口 ↔ 设置窗口的唯一通道名。
const String kTaskSettingsChannelName = 'lifeos/task_settings';

/// 原生侧挂在设置窗口上的窗口控制通道（见 MainFlutterWindow.swift）。
const String kDesktopWindowChannelName = 'lifeos/desktop_window';

const WindowMethodChannel _channel = WindowMethodChannel(
  kTaskSettingsChannelName,
  // 只有主窗口注册 handler，所有 engine 都可发起调用。
  mode: ChannelMode.unidirectional,
);

const MethodChannel _desktopWindow = MethodChannel(kDesktopWindowChannelName);

/// 当前 engine 是不是设置辅助窗口。
bool isTaskSettingsWindow(List<String> args) =>
    args.length >= 3 &&
    args[0] == 'multi_window' &&
    args[2] == kTaskSettingsWindowArgument;

/// 第二窗口入口：不触达本地库与后台调度，只渲染设置面板。
Future<void> runTaskSettingsWindow(List<String> args) async {
  runApp(TaskSettingsWindowApp(windowId: args[1]));
}

class TaskSettingsWindowApp extends StatelessWidget {
  const TaskSettingsWindowApp({super.key, required this.windowId});

  final String windowId;

  @override
  Widget build(BuildContext context) {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    return CupertinoApp(
      title: '设置',
      debugShowCheckedModeBanner: false,
      theme: LifeTokens.cupertino(
        dispatcher.platformBrightness,
        dispatcher.accessibilityFeatures.highContrast,
        dispatcher.accessibilityFeatures.boldText,
      ),
      locale: kAppLocale,
      supportedLocales: kAppSupportedLocales,
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      builder: (context, child) => DefaultTextStyle.merge(
        style: const TextStyle(fontFamilyFallback: LifeTokens.cjkFontFallback),
        child: child ?? const SizedBox.shrink(),
      ),
      home: TaskSettingsWindowPage(windowId: windowId),
    );
  }
}

class TaskSettingsWindowPage extends StatefulWidget {
  const TaskSettingsWindowPage({super.key, required this.windowId});

  final String windowId;

  @override
  State<TaskSettingsWindowPage> createState() => _TaskSettingsWindowPageState();
}

class _TaskSettingsWindowPageState extends State<TaskSettingsWindowPage> {
  TaskPreference? _preference;
  List<ReminderList> _ownLists = const [];
  bool _cloudLoginAvailable = false;
  bool _loading = true;
  String? _loadError;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final raw = await _channel.invokeMethod<dynamic>('getState');
      final state = (raw as Map).cast<Object?, Object?>();
      final rawPreference = state['preference'];
      final rawLists = state['lists'];
      if (rawPreference is! Map || rawLists is! List) {
        throw StateError('malformed settings state');
      }
      final preference = TaskPreference.fromJson(
        rawPreference.cast<String, Object?>(),
      );
      final lists = <ReminderList>[
        for (final entry in rawLists)
          if (entry is Map && entry['id'] is String && entry['title'] is String)
            ReminderList(
              id: entry['id'] as String,
              title: entry['title'] as String,
            ),
      ];
      if (!mounted) return;
      setState(() {
        _preference = preference;
        _ownLists = lists;
        _cloudLoginAvailable = state['cloudLoginAvailable'] == true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '无法读取主窗口设置，请关闭本窗口后重试。';
      });
    }
  }

  Future<void> _apply(TaskPreference next) async {
    setState(() {
      _preference = next;
      _syncError = null;
    });
    try {
      await _channel.invokeMethod<dynamic>('apply', next.toJson());
    } catch (_) {
      if (!mounted) return;
      setState(() => _syncError = '改动未能写入主窗口，请重试。');
    }
  }

  Future<void> _reset() async {
    setState(() {
      _preference = TaskPreference.defaults;
      _syncError = null;
    });
    try {
      await _channel.invokeMethod<dynamic>('reset');
    } catch (_) {
      if (!mounted) return;
      setState(() => _syncError = '还原未能写入主窗口，请重试。');
    }
  }

  Future<void> _openCloudLogin() async {
    try {
      await _channel.invokeMethod<dynamic>('openCloudLogin');
    } catch (_) {
      if (!mounted) return;
      setState(() => _syncError = '无法打开主窗口的登录页。');
    }
  }

  /// 关窗不影响主窗口：优先走原生 close（窗口销毁），插件没有 close 时退回 hide。
  Future<void> _close() async {
    try {
      await _desktopWindow.invokeMethod<dynamic>('close');
      return;
    } catch (_) {
      // 原生 close 不可用（旧构建/非 macOS）时至少把窗口藏起来。
    }
    try {
      final controller = await WindowController.fromCurrentEngine();
      await WindowController.fromWindowId(controller.windowId).hide();
    } catch (_) {
      // 连 hide 都不可用时不留未处理异常：窗口由用户点关闭按钮收掉。
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    final loadError = _loadError;
    if (loadError != null) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('设置')),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loadError),
              const SizedBox(height: 12),
              CupertinoButton.filled(
                key: const ValueKey('settings_window_retry'),
                onPressed: _load,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    final syncError = _syncError;
    return Column(
      children: [
        if (syncError != null)
          ColoredBox(
            color: CupertinoColors.systemRed.resolveFrom(context),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  syncError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CupertinoColors.white),
                ),
              ),
            ),
          ),
        Expanded(
          child: TaskSettingsView(
            preference: _preference ?? TaskPreference.defaults,
            ownLists: _ownLists,
            onChanged: _apply,
            onReset: _reset,
            onDone: _close,
            onOpenCloudLogin: _cloudLoginAvailable ? _openCloudLogin : null,
          ),
        ),
      ],
    );
  }
}
