import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'reminder_item.dart';

/// 清单类型（TC-UI-115；对齐服务端 `TodoListDO.listType`）：
/// null/standard = 标准清单；grocery = 采购清单（预设分区模板，不做商品识别——
/// [HT105086](https://support.apple.com/en-us/105086) 降级口径）。
enum ReminderListType {
  standard,
  grocery;

  /// 与服务端字符串互转（openapi `listType` 字段）。
  String get id => name;

  static ReminderListType fromId(String? id) => switch (id) {
        'grocery' => ReminderListType.grocery,
        _ => ReminderListType.standard,
      };
}

/// 自定义智能列表条件（TC-UI-116；对齐 [Mac Smart Lists]
/// (https://support.apple.com/guide/reminders/create-custom-smart-lists-remnfec66479/mac)，
/// P1 首期：标签 + 旗标 两个条件维度，全部 AND 组合）。
@immutable
final class SmartListFilter extends Equatable {
  const SmartListFilter({
    this.tagEquals,
    this.flaggedOnly = false,
  });

  /// 命中标签（null = 不限）。
  final String? tagEquals;

  /// 仅旗标条目。
  final bool flaggedOnly;

  /// 纯函数命中（不依赖仓库；智能列表基线：已完成不进结果）。
  bool matches(ReminderItem item) {
    if (item.isCompleted) return false;
    if (tagEquals != null && !item.tags.contains(tagEquals)) {
      return false;
    }
    if (flaggedOnly && !item.isFlagged) return false;
    return true;
  }

  @override
  List<Object?> get props => [tagEquals, flaggedOnly];
}

/// 采购清单预设分区模板（与服务端 `TodoListDO.GROCERY_PRESET_SECTIONS`
/// 逐字一致；M4 同步后以服务端下发为准）。
const groceryPresetSections = <String>[
  '农产品', '水果', '肉禽蛋', '水产', '乳品烘焙', '零食饮料', '冷冻食品', '日用品',
];
