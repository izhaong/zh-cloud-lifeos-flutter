import 'dart:async';

import '../models/task_preference.dart';

/// 任务偏好端口（TC-UI-120 的持久半边）。
///
/// 未建行时实现层须回 [TaskPreference.defaults] 且**不写库**（GET 不建行是
/// 服务端 `lifeos_task_preference` 已定的口径，客户端照走）。
abstract interface class TaskPreferenceRepository {
  Stream<TaskPreference> watchPreference();

  /// 全量覆盖式保存；`revision` 由实现层递增，调用方传值无效。
  Future<void> savePreference(TaskPreference preference);
}

/// 内存实现：UI 冒烟与偏好契约测试的参考实现（与 Drift 实现同 revision 口径）。
final class InMemoryTaskPreferenceRepository
    implements TaskPreferenceRepository {
  TaskPreference _p = TaskPreference.defaults;
  int _revision = 0;
  final _controller = StreamController<TaskPreference>.broadcast();

  @override
  Stream<TaskPreference> watchPreference() async* {
    yield _p;
    yield* _controller.stream;
  }

  @override
  Future<void> savePreference(TaskPreference preference) async {
    _revision += 1;
    // 走 copyWith 而不是逐字段重建：加字段时不会在这里漏掉一列
    _p = preference.copyWith(revision: _revision);
    _controller.add(_p);
  }
}
