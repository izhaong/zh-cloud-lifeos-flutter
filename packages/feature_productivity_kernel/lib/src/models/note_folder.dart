import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// 记录文件夹模型（契约 §5；树：parentId 空 = 根）。
///
/// 智能文件夹 [smart]=true 时 [filterJson] 描述条件（键见契约 §1：
/// tagNames/folderId/pinned/updatedWithinDays），不存笔记副本。
@immutable
final class NoteFolder extends Equatable {
  const NoteFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.smart = false,
    this.filterJson,
    this.sortOrder = 0,
  });

  final String id;
  final String name;

  /// 父文件夹 id；null = 根。
  final String? parentId;

  /// 是否智能文件夹。
  final bool smart;

  /// 智能文件夹条件 JSON（仅 smart=true）。
  final String? filterJson;

  final int sortOrder;

  @override
  List<Object?> get props => [id, name, parentId, smart, filterJson, sortOrder];
}
