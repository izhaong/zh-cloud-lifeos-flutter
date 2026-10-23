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
    this.remoteId,
    this.completedAt,
    this.sectionId,
    this.deletedAt,
  });

  final String id;
  final String listId;
  final String title;
  final String? notes;
  final bool isCompleted;
  final bool isFlagged;
  final DateTime? dueAt;

  /// 0 = none, 1 = low, 5 = medium, 9 = high（对齐提醒事项习惯）。
  /// 与服务端 0/1/2/3 的映射见 [ReminderPriorityCodec]。
  final int priority;

  /// 标签（Phase 2 存字符串列表；标签管理 UI 后置）。
  final List<String> tags;

  /// 重复规则 id（见 [Recurrence]；null = 不重复）。
  final String? recurrence;

  /// 子任务的父提醒 id；null = 顶层提醒。
  final String? parentId;

  /// 同层排序键（排序契约统一 `sortOrder asc, id asc`）。
  final int sortOrder;

  /// 服务端实体 ID（Spec 028 临时 ID 映射的本地侧；null = 未同步/纯本地）。
  final String? remoteId;

  /// 完成时间（服务端 completedAt 对齐；null = 未完成）。
  final DateTime? completedAt;

  /// 列表内手动分区 id（A15；null = 未分区；跨列表移动时须清空，对齐 TC-API-118）。
  final String? sectionId;

  /// 进入「最近删除」的时间（A10/TC-API-110 本地侧；null = 未在回收窗）。
  final DateTime? deletedAt;

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
    Object? remoteId = const _Unset(),
    Object? completedAt = const _Unset(),
    Object? sectionId = const _Unset(),
    Object? deletedAt = const _Unset(),
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
      remoteId: remoteId is _Clear
          ? null
          : remoteId is _Unset
              ? this.remoteId
              : remoteId as String?,
      completedAt: completedAt is _Clear
          ? null
          : completedAt is _Unset
              ? this.completedAt
              : completedAt as DateTime?,
      sectionId: sectionId is _Clear
          ? null
          : sectionId is _Unset
              ? this.sectionId
              : sectionId as String?,
      deletedAt: deletedAt is _Clear
          ? null
          : deletedAt is _Unset
              ? this.deletedAt
              : deletedAt as DateTime?,
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
        remoteId,
        completedAt,
        sectionId,
        deletedAt,
      ];
}

/// FL ↔ 服务端优先级映射编解码（Issue #3 / TC-KR-110）。
///
/// FL 本地档位 0/1/5/9（none/low/medium/high，对齐 Apple UI 习惯）；
/// 服务端 M1 冻结 0/1/2/3（`TodoTaskBaseVO.priority` @Min(0)@Max(3)）。
/// 越界值一律兜底 0（无），避免脏数据在双端漂移。
class ReminderPriorityCodec {
  ReminderPriorityCodec._();

  static int toServer(int fl) => switch (fl) {
        1 => 1,
        5 => 2,
        9 => 3,
        _ => 0,
      };

  static int fromServer(int server) => switch (server) {
        1 => 1,
        2 => 5,
        3 => 9,
        _ => 0,
      };
}
