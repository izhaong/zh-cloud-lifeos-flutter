// #549：锚点必须认注入的挂钟。
//
// `clockProvider`（#331）的文档写着「测试 override 成固定时刻，让月/年视图的
// 「今天」高亮与 golden 基线确定化」，但 `AnchorDateNotifier` 里两处都用裸
// `DateTime.now()` —— 而锚点决定月视图渲染哪个月、迷你月历显示哪个月。
// 结果是「注入了挂钟却没钉住月份」：跨月跑的红测（TC-CAL-UI-112、#383）就是这么来的。
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 与真实挂钟必须落在**不同桶**：这条断言的量的是「锚点跟着注入的时钟走」，
  // 如果钉的正好是今天，那 P1 变异（退回 DateTime.now）就不会红，判据等于没写。
  final pinned = DateTime(2026, 10, 26, 14, 5);
  final realNow = DateTime.now();

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => pinned)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('前置对照：钉的日期与真实挂钟不在同一月（否则下面的判据恒真）', () {
    expect(
      [pinned.year, pinned.month] != [realNow.year, realNow.month],
      isTrue,
      reason:
          '本机日期若真的落到 2026-10，这条用例就失去分辨力——'
          '请把 pinned 改到与当天不同的月，而不是删掉这条对照',
    );
  });

  test('锚点初值 = 注入挂钟的本地零点（不是裸 DateTime.now）', () {
    final anchor = makeContainer().read(anchorDateProvider);
    expect(
      [anchor.year, anchor.month, anchor.day],
      [pinned.year, pinned.month, pinned.day],
      reason: 'build() 绕过 clockProvider 时，这里会拿到真实今天',
    );
    expect(
      [anchor.hour, anchor.minute, anchor.second],
      [0, 0, 0],
      reason: '锚点仍是零点',
    );
  });

  test('today() 也回到注入挂钟的今天', () {
    final container = makeContainer();
    container
        .read(anchorDateProvider.notifier)
        .set(DateTime(2026, 11, 20, 18, 30));

    container.read(anchorDateProvider.notifier).today();

    final anchor = container.read(anchorDateProvider);
    expect(
      [anchor.year, anchor.month, anchor.day],
      [pinned.year, pinned.month, pinned.day],
      reason: 'today() 里若还写裸 DateTime.now，就会跳回真实今天',
    );
    expect([anchor.hour, anchor.minute], [0, 0], reason: '零点口径与 build() 一致');
  });

  test('默认（不 override）时锚点就是真实今天零点——生产语义不能被改坏', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final anchor = container.read(anchorDateProvider);
    final now = DateTime.now();
    expect(
      [anchor.year, anchor.month, anchor.day],
      [now.year, now.month, now.day],
    );
    expect([anchor.hour, anchor.minute], [0, 0]);
  });
}
