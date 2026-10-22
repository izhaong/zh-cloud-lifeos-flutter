import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

@immutable
final class MemberSession extends Equatable {
  const MemberSession({
    required this.userId,
    required this.tenantId,
    required this.accessToken,
    this.displayName,
  });

  final String userId;
  final String tenantId;
  final String accessToken;
  final String? displayName;

  @override
  List<Object?> get props => [userId, tenantId, accessToken, displayName];
}
