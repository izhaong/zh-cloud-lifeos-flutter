import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shell/pinned_tabs_service.dart';

/// Tab 固定位偏好 Provider（组合根注入 [PinnedTabsService]）。
final pinnedTabsServiceProvider = Provider<PinnedTabsService>((ref) {
  throw UnimplementedError(
    'pinnedTabsServiceProvider 未注入：请在组合根 ProviderScope.overrides '
    '中 overrideWith 提供（main 内 SharedPreferences.getInstance 后构造）。',
  );
}, name: 'pinnedTabsServiceProvider');

/// 徽标计数 Provider（§1.4 徽标占位）。
///
/// key = AppEntry.id；默认 const {}（无徽标）。
/// 数据源由**组合根** override 派生（如任务未完成计数）；壳不 import feature_*。
final shellBadgeCountsProvider = Provider<Map<String, int>>((ref) {
  return const {};
}, name: 'shellBadgeCountsProvider');
