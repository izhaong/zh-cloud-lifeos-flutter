import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// 提醒事项「我的列表」或智能列表元数据（D6 最低字段齐备）。
@immutable
final class ReminderList extends Equatable {
  const ReminderList({
    required this.id,
    required this.title,
    this.colorArgb = 0xFF007AFF,
    this.isSmart = false,
    this.itemCount = 0,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final int colorArgb;
  final bool isSmart;

  /// 未完成条目数（由仓库派生回写）。
  final int itemCount;

  /// 「我的列表」排序键（智能列表固定顺序，不参与）。
  final int sortOrder;

  ReminderList copyWith({
    String? title,
    int? colorArgb,
    int? itemCount,
    int? sortOrder,
  }) {
    return ReminderList(
      id: id,
      title: title ?? this.title,
      colorArgb: colorArgb ?? this.colorArgb,
      isSmart: isSmart,
      itemCount: itemCount ?? this.itemCount,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props =>
      [id, title, colorArgb, isSmart, itemCount, sortOrder];
}
