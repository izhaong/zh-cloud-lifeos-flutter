import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// 应用可声明/请求的能力标识（Phase 0 冻结，实现后置）。
@immutable
final class LifeCapability extends Equatable {
  const LifeCapability(this.id);

  /// 例如 `task.open`、`calendar.viewDay`。
  final String id;

  static const openTask = LifeCapability('task.open');
  static const openTaskList = LifeCapability('task.openList');
  static const viewCalendarDay = LifeCapability('calendar.viewDay');

  @override
  List<Object?> get props => [id];
}
