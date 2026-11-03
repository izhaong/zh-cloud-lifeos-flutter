// #577：主窗口侧的设置窗口宿主。
//
// 设置辅助窗口不直接开数据库：它经通道向这里要状态、把改动交回来，
// 由主窗口用同一份 Provider/仓储落库。这样「偏好只有一个真身」，
// 改动照常触发 `taskPreferenceProvider` 的流更新，主窗口即时生效。
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'task_settings_window.dart';

class TaskSettingsWindowHost extends ConsumerStatefulWidget {
  const TaskSettingsWindowHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TaskSettingsWindowHost> createState() =>
      _TaskSettingsWindowHostState();
}

class _TaskSettingsWindowHostState
    extends ConsumerState<TaskSettingsWindowHost> {
  static const WindowMethodChannel _channel = WindowMethodChannel(
    kTaskSettingsChannelName,
    mode: ChannelMode.unidirectional,
  );

  @override
  void initState() {
    super.initState();
    // 只在 macOS 主窗口注册：其它平台没有第二窗口，测试宿主也没有插件。
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    _channel.setMethodCallHandler(_handle).catchError((Object error) {
      debugPrint('设置窗口通道注册失败：$error');
    });
  }

  @override
  void dispose() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      _channel.setMethodCallHandler(null).catchError((Object error) {
        debugPrint('设置窗口通道注销失败：$error');
      });
    }
    super.dispose();
  }

  Future<Object?> _handle(MethodCall call) async {
    switch (call.method) {
      case 'getState':
        final preference = await ref.read(taskPreferenceProvider.future);
        final lists = await ref.read(reminderListsProvider.future);
        return {
          'preference': preference.toJson(),
          'lists': [
            for (final list in lists)
              if (!list.isSmart) {'id': list.id, 'title': list.title},
          ],
          'cloudLoginAvailable': taskSettingsCloudLogin.value != null,
        };
      case 'apply':
        final arguments = call.arguments;
        if (arguments is! Map) {
          throw PlatformException(
            code: 'bad-arguments',
            message: 'apply 缺少偏好参数',
          );
        }
        final next = TaskPreference.fromJson(arguments.cast<String, Object?>());
        await ref.read(taskPreferenceRepositoryProvider).savePreference(next);
        return null;
      case 'reset':
        // 「还原」= 视图态记忆一并清零 + 写回契约默认（与应用内页面同口径）。
        ref.read(showCompletedByListProvider.notifier).reset();
        await ref
            .read(taskPreferenceRepositoryProvider)
            .savePreference(TaskPreference.defaults);
        return null;
      case 'openCloudLogin':
        final opener = taskSettingsCloudLogin.value;
        if (opener == null) {
          throw PlatformException(code: 'no-opener', message: '主窗口没有可用的登录入口');
        }
        // 登录页属于主窗口：先把主窗口提到前面，再走它的既有入口。
        final controller = await WindowController.fromCurrentEngine();
        await WindowController.fromWindowId(controller.windowId).show();
        opener();
        return null;
      default:
        throw MissingPluginException('未知设置窗口方法：${call.method}');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
