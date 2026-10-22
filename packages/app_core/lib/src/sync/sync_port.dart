/// 同步端口：开源仓仅 Noop；真实 pull/push 只在私有 cloud。
abstract interface class SyncPort {
  Future<void> pull();
  Future<void> push();
}

final class NoopSyncPort implements SyncPort {
  const NoopSyncPort();

  @override
  Future<void> pull() async {}

  @override
  Future<void> push() async {}
}
