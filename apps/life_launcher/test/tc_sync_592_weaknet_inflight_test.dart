import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 壳根组件在 main.dart（无库导出文件；测试直接引用）
// ignore: implementation_imports
import 'package:life_launcher/main.dart' show LifeLauncherApp;
// ignore: implementation_imports
import 'package:life_launcher/shell/pinned_tabs_service.dart' show PinnedTabsService;
// ignore: implementation_imports
import 'package:life_launcher/shell_providers.dart' show pinnedTabsServiceProvider;

/// FL #592（拆自 #473 第 3 项后半）：已登录 + 有待发变更时，弱网同步「进行中」与
/// 「失败后」的界面观感取证。
///
/// 为什么不是真机限速：AVD 在 `wm size`/`wm density` override 下 `input tap` 完全不生效
/// （本轮实测：override 前后各点 5 处，`keyevent` 有效而 `tap` 无效），而紧凑档（手机竖屏）
/// 又没有设置入口（`#592` 留言里的 uiautomator 节点清单里无 `设置`），登录态在 Android
/// 侧驱动不出来。这里把「同步进行中」的窗口长度变成我说了算的常量——端口挂起即进行中、
/// 端口抛错即失败——判据在 CI 里可复算，比 GPRS 碰运气硬。
class _ControlledSyncPort implements SyncPort {
  int pushCalls = 0;
  int pullCalls = 0;
  Completer<void>? _gate;

  @override
  Future<void> push() {
    pushCalls++;
    final c = Completer<void>();
    _gate = c;
    return c.future;
  }

  @override
  Future<void> pull() {
    pullCalls++;
    final c = Completer<void>();
    _gate = c;
    return c.future;
  }

  /// 在途请求超时失败（模拟弱网丢包/超时）。
  void failInFlight() {
    final c = _gate;
    _gate = null;
    c?.completeError(StateError('SocketException: 连接超时（受控注入）'), StackTrace.empty);
  }

  void finishInFlight() {
    final c = _gate;
    _gate = null;
    c?.complete();
  }
}

class _LoggedInAuthPort implements AuthPort {
  const _LoggedInAuthPort();

  @override
  Future<MemberSession?> currentSession() async => const MemberSession(
        userId: '309',
        tenantId: '1',
        accessToken: 'probe-token',
      );

  @override
  Future<MemberSession> login({
    required String username,
    required String password,
  }) async =>
      const MemberSession(
        userId: '309',
        tenantId: '1',
        accessToken: 'probe-token',
      );

  @override
  Future<void> logout() async {}

  @override
  Future<MemberSession?> refresh() async => null;
}

void main() {
  final fixed = DateTime(2026, 11, 3, 9, 30);

  Future<(_ControlledSyncPort, InMemoryReminderRepository)> pumpLoggedIn(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final repo = InMemoryReminderRepository(seedSampleData: false)
      ..nowForTest = fixed;
    // 前提：本机有一条未推的改动（今天到期，所以「今天」页能看见它）。
    await repo.upsertItem(
      ReminderItem(
        id: 'r-pending',
        listId: 'smart.today',
        title: '弱网取证项',
        dueAt: fixed.add(const Duration(hours: 1)),
        createdAt: fixed.subtract(const Duration(hours: 1)),
      ),
    );
    final port = _ControlledSyncPort();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authPortProvider.overrideWithValue(const _LoggedInAuthPort()),
          syncPortProvider.overrideWithValue(port),
          reminderRepositoryProvider.overrideWithValue(repo),
          pinnedTabsServiceProvider.overrideWithValue(PinnedTabsService(prefs)),
          clockProvider.overrideWithValue(() => fixed),
        ],
        child: const LifeLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();
    return (port, repo);
  }

  /// 回前台 = 续一轮同步的真实触发点（`_LifeLauncherAppState.didChangeAppLifecycleState`）。
  Future<void> resume(WidgetTester tester) async {
    // 合法档位链：resumed → inactive → resumed（框架不允许 paused 直接跳 resumed）。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    // 让 `Future(() async { await port.push(); ... })` 跑到挂起点。
    // 必须带时长泵：裸 `pump()` 不推进 FakeAsync 的微任务队列，push 计数会停在 0
    // （本轮踩过，别退回裸 pump）。
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('#592 登录态弱网同步进行中：一轮真发起了（push 计数 1），'
      '但界面无任何「同步中」形状（无转圈、无进度、无文案）', (tester) async {
    final (port, _) = await pumpLoggedIn(tester);
    expect(port.pushCalls, 0, reason: '回前台之前不该有同步在途');

    await resume(tester);

    // 前提成立：这一轮确实卡在网络上，而不是压根没跑。
    expect(port.pushCalls, 1, reason: '回前台应续一轮，且 push 先于 pull');
    expect(port.pullCalls, 0, reason: 'push 未回执，pull 不该开始');

    // 观感判据（本轮量到的结论：壳对同步在途是静默的）。
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    for (final copy in const ['同步中', '正在同步', '同步中…', '上传中', '同步失败']) {
      expect(find.text(copy), findsNothing, reason: '不该出现「$copy」');
    }
    // 正向对照：本地数据照常渲染（否则「无指示」可能只是整页没画）。
    expect(find.text('弱网取证项'), findsOneWidget);

    await expectLater(
      find.byType(LifeLauncherApp),
      matchesGoldenFile('goldens/desktop_1280_sync_inflight.png'),
    );
    port.finishInFlight();
    await tester.pump();
  });

  testWidgets('#592 登录态弱网同步失败后：不打扰用户（无报错文案），本地待发项仍在',
      (tester) async {
    final (port, repo) = await pumpLoggedIn(tester);
    await resume(tester);
    expect(port.pushCalls, 1);

    port.failInFlight();
    await tester.pump();
    await tester.pump();

    expect(find.text('同步失败'), findsNothing);
    expect(find.text('网络异常，请重试'), findsNothing);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    // 失败不清队：本地那条未推改动还在（离线优先红线）。
    final items = await repo.watchItems().first;
    expect(items.any((e) => e.id == 'r-pending'), isTrue,
        reason: '同步失败不得丢本地待发数据');

    // 冻结的不变量：失败后与「进行中」两帧**逐字节相同**（md5 见 Issue 收口留言），
    // 所以这里复用同一张 golden——将来谁加了报错横幅，本用例当场变红。
    await expectLater(
      find.byType(LifeLauncherApp),
      matchesGoldenFile('goldens/desktop_1280_sync_inflight.png'),
    );
  });
}
