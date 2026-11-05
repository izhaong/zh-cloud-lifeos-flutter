import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// 记录标签模型（契约 §1：用户级名字，多对多挂笔记）。
@immutable
final class NoteTag extends Equatable {
  const NoteTag({
    required this.id,
    required this.name,
    this.color,
  });

  final String id;
  final String name;

  /// 颜色 #RRGGBB 或 #RRGGBBAA；null = 默认色。
  final String? color;

  @override
  List<Object?> get props => [id, name, color];
}
