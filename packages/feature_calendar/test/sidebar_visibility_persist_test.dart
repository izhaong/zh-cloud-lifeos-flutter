import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// #254：日历侧栏显隐必须真的落到 shared_preferences。
///
/// 生产上组合根曾漏注入 `sidebarPrefsProvider`，notifier 读到 null 就永远回落
/// 「显示」并静默不写——用户每次重启都要重新收一次侧栏。这里用同一份 mock
/// prefs 建两个容器，钉住「第二个容器读回第一个容器的选择」。
void main() {
  test('侧栏隐藏后重新建容器仍是隐藏（真持久化）', () async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();

    final first = ProviderContainer(
      overrides: [sidebarPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(first.dispose);
    expect(first.read(sidebarVisibleProvider), isTrue, reason: '默认显示');
    first.read(sidebarVisibleProvider.notifier).set(false);
    // 等 setBool 落盘（mock 实现是同步的，await 一次更稳）
    await prefs.reload();

    final second = ProviderContainer(
      overrides: [sidebarPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(second.dispose);
    expect(
      second.read(sidebarVisibleProvider),
      isFalse,
      reason: '新容器必须读回「隐藏」，否则就是没持久化',
    );
  });

  test('未注入 prefs 时回落显示且不抛（旧行为保留）', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(sidebarVisibleProvider), isTrue);
    // 不注入时 toggle 不应崩
    container.read(sidebarVisibleProvider.notifier).toggle();
    expect(container.read(sidebarVisibleProvider), isFalse);
  });
}
