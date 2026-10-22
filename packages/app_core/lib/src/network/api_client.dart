import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../auth/member_session.dart';

/// 统一 dio 客户端骨架（信封 `{code,msg,data}` 后续接）。
final class ApiClient {
  ApiClient({
    required String baseUrl,
    Logger? logger,
    this._sessionProvider,
  })  : _log = logger ?? Logger(printer: PrettyPrinter(methodCount: 0)),
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final session = _sessionProvider?.call();
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
            options.headers['tenant-id'] = session.tenantId;
          }
          handler.next(options);
        },
        onError: (error, handler) {
          _log.w('HTTP ${error.response?.statusCode} ${error.requestOptions.uri}');
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  final Logger _log;
  final MemberSession? Function()? _sessionProvider;
}
