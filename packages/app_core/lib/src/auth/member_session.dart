import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

@immutable
final class MemberSession extends Equatable {
  const MemberSession({
    required this.userId,
    required this.tenantId,
    required this.accessToken,
    this.refreshToken,
    this.displayName,
  });

  final String userId;
  final String tenantId;
  final String accessToken;

  /// 刷新令牌（TC-SYNC-114 用；登录接口返回什么这里就存什么，缺失视为不可刷新）。
  final String? refreshToken;
  final String? displayName;

  @override
  List<Object?> get props =>
      [userId, tenantId, accessToken, refreshToken, displayName];
}
