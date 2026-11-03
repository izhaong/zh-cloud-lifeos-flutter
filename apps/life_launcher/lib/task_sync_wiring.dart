import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// #595（口径 1）：任务域「上次成功同步」时间戳的落点。
const String taskLastSyncKey = 'lifeos.task.last_sync_at_ms';

/// 包一层任务域协调器：一轮走完后盖时间戳；**失败不盖**（也不清队，那是协调器
/// 既有口径）。这样「上次同步」只说真话——没成功过就是「尚未同步」。
///
/// 依赖取成三段闭包而不是具体 `TaskSyncCoordinator`：组合根本来就是它，
/// 而本轮要验的只有「成功才盖戳」这一条，用闭包造假比造四套端口假件干净。
final class TaskSyncRound implements SyncPort {
  TaskSyncRound({
    required this.onPush,
    required this.onPull,
    required this.onSyncOnce,
    required this.prefs,
    required this.clock,
  });

  final Future<void> Function() onPush;
  final Future<void> Function() onPull;
  final Future<void> Function() onSyncOnce;
  final SharedPreferences prefs;
  final DateTime Function() clock;

  /// 单独 push 不盖戳：这一轮还没走完（回前台路径紧接着会调 [pull]）。
  @override
  Future<void> push() => onPush();

  /// 回前台续一轮：push → pull，pull 回执即视为这一轮成功。
  @override
  Future<void> pull() async {
    await onPull();
    await _stamp();
  }

  /// 冷启动那一轮（协调器的 syncOnce = 先推后拉）。
  Future<void> runOnce() async {
    await onSyncOnce();
    await _stamp();
  }

  Future<void> _stamp() =>
      prefs.setInt(taskLastSyncKey, clock().millisecondsSinceEpoch);
}

/// 设置弹层要的状态：会话 + 待发条数 + 上次成功同步时刻。
///
/// 未登录直接返回 `signedOut()`——不发 `pending()` 查询，也不让 UI 摆出
/// 「待推 0 条 · 上次同步 …」这种对离线用户没意义的话。
Future<SyncStatus> readTaskSyncStatus({
  required AuthPort auth,
  required SyncOutbox outbox,
  required SharedPreferences prefs,
}) async {
  final session = await auth.currentSession();
  if (session == null) return const SyncStatus.signedOut();
  final pending = await outbox.pending();
  final ms = prefs.getInt(taskLastSyncKey);
  return SyncStatus(
    loggedIn: true,
    pendingCount: pending.length,
    lastSyncAt: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
  );
}
