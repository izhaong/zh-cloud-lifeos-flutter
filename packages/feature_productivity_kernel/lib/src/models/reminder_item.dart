import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

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

  ReminderItem copyWith({
    String? title,
    String? notes,
    bool? isCompleted,
    bool? isFlagged,
    DateTime? dueAt,
    int? priority,
  }) {
    return ReminderItem(
      id: id,
      listId: listId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      isFlagged: isFlagged ?? this.isFlagged,
      dueAt: dueAt ?? this.dueAt,
      priority: priority ?? this.priority,
    );
  }

  @override
  List<Object?> get props =>
      [id, listId, title, notes, isCompleted, isFlagged, dueAt, priority];
}
