import 'package:flutter_riverpod/flutter_riverpod.dart';

/// #595（口径 1）：同步状态的展示契约。
///
/// 产品裁定走「不打扰」这一档——主界面**不加**常驻转圈或失败横幅，
/// #592 量到的「在途与失败两帧逐字节相同」这条不变量继续成立；
/// 状态只放在用户主动查看的设置弹层里，可查证、不新增视觉元素。
final class SyncStatus {
  const SyncStatus({
    required this.loggedIn,
    required this.pendingCount,
    this.lastSyncAt,
  });

  /// 开源 / 未注入时的默认：未登录（不摆没消费者的样子）。
  const SyncStatus.signedOut()
    : loggedIn = false,
      pendingCount = 0,
      lastSyncAt = null;

  /// 是否已有登录会话；false 时 [settingsLabel] 恒为 null。
  final bool loggedIn;

  /// 本机待发（未推上云）的变更条数。
  final int pendingCount;

  /// 上一次**成功**走完一轮同步的时刻；从未成功过则 null。
  final DateTime? lastSyncAt;

  /// 设置弹层「云同步」行的副标题文案。
  String? get settingsLabel {
    if (!loggedIn) return null;
    final last = lastSyncAt == null
        ? '尚未同步'
        : '上次同步 ${_hhmm(lastSyncAt!)}';
    return '待推 $pendingCount 条 · $last';
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}'
      ':${t.minute.toString().padLeft(2, '0')}';
}

/// 同步状态 Provider：默认「未登录」。真值由组合根 override——
/// 读发件箱待发条数 + 上次成功同步时间戳 + 当前会话。
///
/// 用 autoDispose：设置弹层每次打开都是新订阅，拿到的待发数是当下的，
/// 不是上一次打开时的快照。
final syncStatusProvider = FutureProvider.autoDispose<SyncStatus>(
  (ref) async => const SyncStatus.signedOut(),
);
