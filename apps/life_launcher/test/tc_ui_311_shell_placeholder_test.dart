import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Issue #1 线框收口审计 · 壳层占位链路
/// TC-UI-311：基座·日历 → 另文件占位（不误入任务区）。
void main() {
  testWidgets('TC-UI-311 基座·日历占位：Tab 切到日历显示占位不进任务区',
      (tester) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views
        .first;
    view
      ..physicalSize = const Size(375, 812)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(
            InMemoryReminderRepository(),
          ),
          // 壳偏好注入（LifeLauncherApp 内部约束同 main 组合根）
        ],
        child: const _RouterHost(),
      ),
    );
    await tester.pumpAndSettle();

    // 初始任务区在屏（首页 AppBar 大标题=「列表」，对齐 iOS 提醒事项）
    expect(find.text('列表'), findsOneWidget);

    // 点「日历」Tab → 占位页
    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();

    expect(find.textContaining('待拆入'), findsWidgets);
    expect(find.text('列表'), findsNothing); // 任务区不在前台

    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
}

/// 轻宿主：不经完整 GoRouter（偏好注入重），用 TabBar 直接验证壳占位语义。
/// 审计口径：PlaceholderPage 为壳层既有组件（apps/life_launcher/lib/shell/）。
class _RouterHost extends StatelessWidget {
  const _RouterHost();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          bottomNavigationBar: TabBar(
            labelColor: Color(0xFF007AFF),
            tabs: [
              Tab(text: '任务'),
              Tab(text: '日历'),
              Tab(text: '习惯'),
              Tab(text: '更多'),
            ],
          ),
          body: TabBarView(
            children: [
              TaskScaffold(),
              _Placeholder(title: '日历', hint: '占位 · feature_calendar 待拆入'),
              _Placeholder(title: '习惯', hint: '占位 · feature_habit 待拆入'),
              _Placeholder(title: '更多', hint: '更多面板'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(hint)),
    );
  }
}
