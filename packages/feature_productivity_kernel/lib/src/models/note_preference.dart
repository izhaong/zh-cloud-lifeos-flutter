import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// 记录侧本地偏好（TC-NOTE-UI-111；一用户一行，照 `TaskPreference` 先例）。
///
/// 「默认文件夹」null = 未设置（保存到当前所选文件夹）；`sortMode` 存档位名串，
/// 解码方（feature_note）负责把未知串退回默认档，不让一条脏值炸了设置页。
@immutable
final class NotePreference extends Equatable {
  const NotePreference({
    this.defaultFolderId,
    this.sortMode = 'custom',
    this.groupByDate = true,
    this.beginWith = 'nothing',
    this.defaultTextSize = 16,
    this.revision = 1,
  });

  /// 新备忘录默认保存到的文件夹（null = 跟随当前文件夹）。
  final String? defaultFolderId;

  /// 排序档位名（`custom`/`title`/`updated`；未知串按 `custom` 处理）。
  final String sortMode;

  /// 默认正文文本大小（磅；#463，Apple「默认文本大小」滑块）。
  final int defaultTextSize;

  /// 列表是否按日期分组（#392，Apple「按日期分组备忘录」勾选）。
  final bool groupByDate;

  /// 新建备忘录的开头格式档位名（#392，Apple「新备忘录开头格式」弹出菜单；
  /// `nothing`/`title`/`body`/`checklist`，未知串按 `nothing` 处理）。
  final String beginWith;

  /// 保存次数（每次保存 +1，与任务/日历偏好同口径）。
  final int revision;

  /// 契约默认值（无行时实现层回这个值，不写库）。
  static const NotePreference defaults = NotePreference();

  NotePreference copyWith({
    String? defaultFolderId,
    bool clearDefaultFolderId = false,
    String? sortMode,
    bool? groupByDate,
    String? beginWith,
    int? defaultTextSize,
    int? revision,
  }) {
    return NotePreference(
      // 与 TaskPreference 同理：`clear*` 才是「置为未设置」的通道，
      // 不能靠 null 区分「没传」与「要清空」。
      defaultFolderId: clearDefaultFolderId
          ? null
          : (defaultFolderId ?? this.defaultFolderId),
      sortMode: sortMode ?? this.sortMode,
      groupByDate: groupByDate ?? this.groupByDate,
      beginWith: beginWith ?? this.beginWith,
      defaultTextSize: defaultTextSize ?? this.defaultTextSize,
      revision: revision ?? this.revision,
    );
  }

  @override
  List<Object?> get props => [
    defaultFolderId,
    sortMode,
    groupByDate,
    beginWith,
    defaultTextSize,
    revision,
  ];
}
