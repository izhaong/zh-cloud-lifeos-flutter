import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'reminder_section.dart';

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
    this.sections = const [],
    this.groupName,
  });

  final String id;
  final String title;
  final int colorArgb;
  final bool isSmart;

  /// 未完成条目数（由仓库派生回写）。
  final int itemCount;

  /// 「我的列表」排序键（智能列表固定顺序，不参与）。
  final int sortOrder;

  /// 手动分区元数据（我的列表；TC-KR-118）。
  final List<ReminderSection> sections;

  /// 列表分组名（TC-UI-118；null = 不分组平铺；对等矩阵 #19 降级=列表分组）。
  final String? groupName;

  ReminderList copyWith({
    String? title,
    int? colorArgb,
    int? itemCount,
    int? sortOrder,
    List<ReminderSection>? sections,
    Object? groupName = const _GrpUnset(),
  }) {
    return ReminderList(
      id: id,
      title: title ?? this.title,
      colorArgb: colorArgb ?? this.colorArgb,
      isSmart: isSmart,
      itemCount: itemCount ?? this.itemCount,
      sortOrder: sortOrder ?? this.sortOrder,
      sections: sections ?? this.sections,
      groupName: groupName is _GrpUnset ? this.groupName : groupName as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, title, colorArgb, isSmart, itemCount, sortOrder, sections,
       groupName];
}


/// copyWith groupName 三态哨兵（null=置空/不传=保持）。
@immutable
class _GrpUnset {
  const _GrpUnset();
}
