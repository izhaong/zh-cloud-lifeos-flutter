import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// 记录（备忘录）模型（契约 §5：字段与 lifeos_note 表一一对应）。
///
/// 正文两份：[bodyDelta]（Quill Delta JSON；锁定时为客户端 AES-GCM 密文
/// Base64）与 [bodyText]（纯文本，搜索用；锁定时强制空）。
/// 锁定语义：开源包只存标志与密文字符串，真加解密在 cloud 包。
@immutable
final class Note extends Equatable {
  const Note({
    required this.id,
    required this.folderId,
    required this.title,
    this.bodyDelta = '',
    this.bodyText = '',
    this.pinned = false,
    this.locked = false,
    this.checklistTotal = 0,
    this.checklistDone = 0,
    this.tagNames = const [],
    this.sortOrder = 0,
    this.deletedAt,
    this.revision = 0,
    this.clientUpdatedAt = 0,
  });

  final String id;
  final String folderId;
  final String title;

  /// Quill Delta JSON（锁定时为密文 Base64）。
  final String bodyDelta;

  /// 纯文本（搜索用；锁定时强制空）。
  final String bodyText;

  final bool pinned;
  final bool locked;
  final int checklistTotal;
  final int checklistDone;

  /// 标签名列表（Phase 1 内存态；Drift 归 F-02 落表）。
  final List<String> tagNames;

  final int sortOrder;

  /// 进入「最近删除」时间；null = 未删（30 天回收窗）。
  final DateTime? deletedAt;

  /// 乐观锁版本（保存冲突判定用）。
  final int revision;

  /// 客户端更新时间戳（毫秒）。
  final int clientUpdatedAt;

  @override
  List<Object?> get props => [
        id,
        folderId,
        title,
        bodyDelta,
        bodyText,
        pinned,
        locked,
        checklistTotal,
        checklistDone,
        tagNames,
        sortOrder,
        deletedAt,
        revision,
        clientUpdatedAt,
      ];
}
