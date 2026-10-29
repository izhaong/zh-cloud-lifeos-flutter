// #451：设置里的「标记数量含今天到期」必须能落库并可读回。
//
// 直接测仓储往返（`taskPreferenceProvider` 的首帧是 AsyncLoading，
// 用它写单测要等流，容易写成挂住的测试——#433 的教训：卡住的测试比红更糟）。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('#451 关闭后落库为 false，读回仍 false', () async {
    final repo = InMemoryTaskPreferenceRepository();

    await repo.savePreference(
        const TaskPreference(badgeIncludesTodayDue: false));

    final pref = await repo.watchPreference().first;
    expect(pref.badgeIncludesTodayDue, isFalse);
  });

  test('#451 默认值为 true（老用户不因升级丢徽标）', () async {
    final repo = InMemoryTaskPreferenceRepository();
    final pref = await repo.watchPreference().first;
    expect(pref.badgeIncludesTodayDue, isTrue);
  });

  test('#451 其它设置不受影响（copyWith 不误清）', () async {
    final repo = InMemoryTaskPreferenceRepository();
    await repo.savePreference(const TaskPreference(
      suggestLists: false,
      badgeIncludesTodayDue: false,
    ));

    final pref = await repo.watchPreference().first;
    expect(pref.suggestLists, isFalse);
    expect(pref.badgeIncludesTodayDue, isFalse);
  });
}
