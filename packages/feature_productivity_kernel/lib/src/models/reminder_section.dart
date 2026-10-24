import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// 手动分区（Apple Reminders「Sections」对齐，HT119953 / TC-KR-118）。
///
/// 轻量元数据挂列表（非独立树）；条目经 `ReminderItem.sectionId` 挂靠；
/// 与 dueAt 日桶分组互斥（一列表一种分组模式，M0 拍板）。
@immutable
final class ReminderSection extends Equatable {
  const ReminderSection({
    required this.id,
    required this.title,
    this.sortOrder = 0,
  });

  final String id;
  final String title;

  /// 同列表内排序键（`sortOrder asc, id asc` 契约同条目）。
  final int sortOrder;

  ReminderSection copyWith({String? title, int? sortOrder}) {
    return ReminderSection(
      id: id,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [id, title, sortOrder];
}
