import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_registry.dart';

/// Tab 固定位偏好的壳内本地服务（§1.4 Phase 4）。
///
/// - 存储：单 key `shell.pinned_tab_ids`（StringList，有序）
/// - 缺 key = 默认全固定（注册表序，首启零配置）
/// - 空列表合法（仅剩「更多」）
/// - 读时 normalize：过滤未知 id、去重、≤[maxPinnedTabs] 截断
/// - 写即生效（勿内存暂存批量提交）；[changes] 供壳层响应式刷新
class PinnedTabsService {
  PinnedTabsService(this._prefs) {
    _cache.value = read();
  }

  static const prefsKey = 'shell.pinned_tab_ids';

  final SharedPreferences _prefs;
  final _cache = ValueNotifier<List<String>>(const []);

  /// 固定序列变更流（写操作后广播；壳层 listen 刷新底栏/面板）。
  Listenable get changes => _cache;

  /// 当前固定序列（normalize 后）。
  List<String> read() {
    final raw = _prefs.getStringList(prefsKey);
    if (raw == null) {
      // 缺 key：默认全固定（注册表序）
      return List<String>.from(
        installedApps.map((e) => e.id),
        growable: false,
      );
    }
    return normalize(raw);
  }

  /// 写入固定序列（normalize 后落盘 + 广播）。
  Future<void> write(List<String> ids) async {
    final normalized = normalize(ids);
    await _prefs.setStringList(prefsKey, normalized);
    _cache.value = normalized;
  }

  /// normalize：滤未知 id → 去重（保序）→ ≤5 截断。
  static List<String> normalize(List<String> ids) {
    final known = {for (final e in installedApps) e.id};
    final seen = <String>{};
    final result = <String>[];
    for (final id in ids) {
      if (!known.contains(id) || seen.contains(id)) continue;
      seen.add(id);
      result.add(id);
      if (result.length >= maxPinnedTabs) break;
    }
    return List<String>.unmodifiable(result);
  }
}
