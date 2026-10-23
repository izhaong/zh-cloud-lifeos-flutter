import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'recurrence.dart';

/// copyWith 未传参哨兵（默认参数值；私有类型即身份）。
@immutable
class _Unset {
  const _Unset();
}

/// copyWith 显式置空哨兵（用户传 [ReminderItem.clear] 时的值）。
///
/// 与 [_Unset] 是**不同类型**，从而区分「未传参（保持）」与
/// 「显式置空（→ null）」两种语义。
@immutable
class _Clear {
  const _Clear();
}

/// 提醒事项条目（D6 最低字段齐备，可演进）。
@immutable
final class ReminderItem extends Equatable {
  const ReminderItem({
    required this.id,
    required this.listId,
    required this.title,
    this.notes,
    this.isCompleted = false,
    this.isFlagged = false,
    this.dueAt,
    this.priority = 0,
    this.tags = const [],
    this.recurrence,
    this.parentId,
    this.sortOrder = 0,
  });

  final String id;
  final String listId;
  final String title;
  final String? notes;
  final bool isCompleted;
  final bool isFlagged;
  final DateTime? dueAt;

  /// 0 = none, 1 = low, 5 = medium, 9 = high（对齐提醒事项习惯）。
  final int priority;

  /// 标签（Phase 2 存字符串列表；标签管理 UI 后置）。
  final List<String> tags;

  /// 重复规则 id（见 [Recurrence]；null = 不重复）。
  final String? recurrence;

  /// 子任务的父提醒 id；null = 顶层提醒。
  final String? parentId;

  /// 同层排序键（排序契约统一 `sortOrder asc, id asc`）。
  final int sortOrder;

  bool get isSubtask => parentId != null;

  Recurrence? get recurrenceRule => Recurrence.fromId(recurrence);

  /// 哨兵：传给 [copyWith] 的可空字段参数以**显式置空**该字段。
  ///
  /// ```dart
  /// item.copyWith(notes: ReminderItem.clear); // notes → null
  /// item.copyWith(notes: '新备注');            // notes → '新备注'
  /// item.copyWith();                           // notes 保持
  /// ```
  static const Object clear = _Clear();

  /// 全量回写式编辑的唯一入口（端口 `upsertItem` 消费）。
  ReminderItem copyWith({
    String? title,
    Object? notes = const _Unset(),
    bool? isCompleted,
    bool? isFlagged,
    Object? dueAt = const _Unset(),
    int? priority,
    Object? tags = const _Unset(),
    Object? recurrence = const _Unset(),
    Object? parentId = const _Unset(),
    int? sortOrder,
  }) {
    return ReminderItem(
      id: id,
      listId: listId,
      title: title ?? this.title,
      notes: notes is _Clear
          ? null
          : notes is _Unset
              ? this.notes
              : notes as String?,
      isCompleted: isCompleted ?? this.isCompleted,
      isFlagged: isFlagged ?? this.isFlagged,
      dueAt: dueAt is _Clear
          ? null
          : dueAt is _Unset
              ? this.dueAt
              : dueAt as DateTime?,
      priority: priority ?? this.priority,
      tags: tags is _Clear
          ? const <String>[]
          : tags is _Unset
              ? this.tags
              : tags as List<String>,
      recurrence: recurrence is _Clear
          ? null
          : recurrence is _Unset
              ? this.recurrence
              : recurrence as String?,
      parentId: parentId is _Clear
          ? null
          : parentId is _Unset
              ? this.parentId
              : parentId as String?,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [
        id,
        listId,
        title,
        notes,
        isCompleted,
        isFlagged,
        dueAt,
        priority,
        tags,
        recurrence,
        parentId,
        sortOrder,
      ];
}
