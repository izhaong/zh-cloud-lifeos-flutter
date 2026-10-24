import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'reminder_list_type.dart';
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
    this.listType = ReminderListType.standard,
    this.smartFilter,
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

  /// 清单类型（TC-UI-115；standard/grocery）。
  final ReminderListType listType;

  /// 自定义智能列表条件（TC-UI-116；null = 非自定义智能列表）。
  final SmartListFilter? smartFilter;

  /// 建 grocery 列表：预置 8 分区模板（农产品→日用品，sortOrder 0–7）。
  factory ReminderList.createGroceryList({
    required String id,
    required String title,
    int colorArgb = 0xFF34C759,
  }) {
    return ReminderList(
      id: id,
      title: title,
      colorArgb: colorArgb,
      listType: ReminderListType.grocery,
      sections: [
        for (var i = 0; i < groceryPresetSections.length; i++)
          ReminderSection(
            id: 'sec_${id}_$i',
            title: groceryPresetSections[i],
            sortOrder: i,
          ),
      ],
    );
  }

  ReminderList copyWith({
    String? title,
    int? colorArgb,
    int? itemCount,
    int? sortOrder,
    List<ReminderSection>? sections,
    Object? groupName = const _GrpUnset(),
    ReminderListType? listType,
    SmartListFilter? smartFilter,
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
      listType: listType ?? this.listType,
      smartFilter: smartFilter ?? this.smartFilter,
    );
  }

  @override
  List<Object?> get props =>
      [id, title, colorArgb, isSmart, itemCount, sortOrder, sections,
       groupName, listType, smartFilter];
}


/// copyWith groupName 三态哨兵（null=置空/不传=保持）。
@immutable
class _GrpUnset {
  const _GrpUnset();
}
