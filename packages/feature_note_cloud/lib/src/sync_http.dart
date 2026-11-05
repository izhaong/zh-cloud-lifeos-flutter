/// 同步 HTTP 端口（契约 §6：RestSyncPort 复用任务云同步的假 HTTP 测试写法）。
abstract interface class NoteSyncHttp {
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body);
}
