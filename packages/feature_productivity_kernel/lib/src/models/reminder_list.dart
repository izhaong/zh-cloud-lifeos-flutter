import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// 提醒事项「我的列表」或智能列表元数据。
@immutable
final class ReminderList extends Equatable {
  const ReminderList({
    required this.id,
    required this.title,
    this.colorArgb = 0xFF007AFF,
    this.isSmart = false,
    this.itemCount = 0,
  });

  final String id;
  final String title;
  final int colorArgb;
  final bool isSmart;
  final int itemCount;

  @override
  List<Object?> get props => [id, title, colorArgb, isSmart, itemCount];
}
