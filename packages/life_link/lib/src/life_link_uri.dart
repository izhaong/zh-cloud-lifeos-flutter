import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'capability.dart';

/// `lifeos://` 深链解析结果（纯数据，无平台跳转）。
@immutable
final class LifeLinkUri extends Equatable {
  const LifeLinkUri({
    required this.capability,
    this.resourceId,
    this.query = const {},
  });

  static const scheme = 'lifeos';

  final LifeCapability capability;
  final String? resourceId;
  final Map<String, String> query;

  /// 解析 `lifeos://task/open?id=42` 这类 URI；失败返回 null。
  static LifeLinkUri? tryParse(Uri uri) {
    if (uri.scheme != scheme) return null;
    final host = uri.host;
    final pathSegs =
        uri.pathSegments.where((s) => s.isNotEmpty).toList(growable: false);
    if (host.isEmpty && pathSegs.isEmpty) return null;

    final capabilityId = pathSegs.isEmpty
        ? host
        : '$host.${pathSegs.first}';
    final resourceId = pathSegs.length > 1
        ? pathSegs[1]
        : uri.queryParameters['id'];

    return LifeLinkUri(
      capability: LifeCapability(capabilityId),
      resourceId: resourceId,
      query: Map<String, String>.unmodifiable(uri.queryParameters),
    );
  }

  Uri toUri() {
    final parts = capability.id.split('.');
    final host = parts.first;
    final path = parts.length > 1
        ? '/${parts.sublist(1).join('/')}${resourceId != null ? '/$resourceId' : ''}'
        : (resourceId != null ? '/$resourceId' : '');
    return Uri(
      scheme: scheme,
      host: host,
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );
  }

  @override
  List<Object?> get props => [capability, resourceId, query];
}
