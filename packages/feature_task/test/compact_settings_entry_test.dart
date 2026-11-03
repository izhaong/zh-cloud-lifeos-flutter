// FL #594：紧凑档（手机竖屏）没有设置入口 ⇒ 「开启云同步 → 登录」这条路在手机上走不通。
// 本用例先把缺口钉红，再实现「列表首页头部齿轮 → 同一份设置弹层」。
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

void main() {
  Future<InMemoryReminderRepository> seed() async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.p', title: '工作'));
    return repo;
  }

  Future<void> pumpCompactHome(
    WidgetTester tester, {
    required VoidCallback onOpenCloudLogin,
  }) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(420, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
    final repo = await seed();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(
          TaskScaffold(onOpenCloudLogin: onOpenCloudLogin),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('#594 紧凑档列表首页有齿轮入口，点开就是同一份设置弹层（含「开启云同步」行）',
      (tester) async {
    var opened = 0;
    await pumpCompactHome(tester, onOpenCloudLogin: () => opened++);

    // 齿轮在，且没把原来的「⋯ 编辑列表」挤掉。
    expect(
      find.byKey(const ValueKey('compact_settings')),
      findsOneWidget,
      reason: '紧凑档必须有设置入口，否则云同步/登录在手机上不可达',
    );
    expect(find.byKey(const ValueKey('home_edit_placeholder')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('compact_settings')));
    await tester.pumpAndSettle();
    expect(find.text('开启云同步'), findsOneWidget,
        reason: '齿轮打开的应是同一份设置弹层');

    await tester.tap(find.text('开启云同步'));
    await tester.pumpAndSettle();
    expect(opened, 1, reason: '点「开启云同步」要真的把登录回调交出去');
  });

  testWidgets('#594 没注入登录回调时，齿轮仍打得开设置、云同步行退成说明文案',
      (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(420, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
    final repo = await seed();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
        child: lifeTestHost(const TaskScaffold()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('compact_settings')));
    await tester.pumpAndSettle();
    expect(find.text('云同步：登录后可用'), findsOneWidget,
        reason: '宿主没给登录回调时，行仍在、只是不可点成登录');
    expect(find.text('开启云同步'), findsNothing);
  });
}
