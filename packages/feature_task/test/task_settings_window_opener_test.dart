import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #577：设置入口要能切到「独立辅助窗口」。
///
/// 这里不拉起真实窗口（widget 测试没有 desktop_multi_window 原生端），
/// 只验证**路由选择**：注入了窗口打开器就走它、不再 push 应用内页面；
/// 未注入（其它平台/测试）才回退应用内页面。真窗口行为归 #473 真人走查。
Future<ValueNotifier<LifeMenuAction?>> _pump(
  WidgetTester tester, {
  required ReminderRepository repo,
  TaskSettingsWindowOpener? opener,
}) async {
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view
    ..physicalSize = const Size(1366, 1024)
    ..devicePixelRatio = 1.0;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
  final commands = ValueNotifier<LifeMenuAction?>(null);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        lifeMenuCommandsProvider.overrideWithValue(commands),
        if (opener != null)
          taskSettingsWindowOpenerProvider.overrideWith((ref) => opener),
      ],
      child: const MaterialApp(home: TaskScaffold(openListId: 'smart.today')),
    ),
  );
  await tester.pumpAndSettle();
  return commands;
}

Future<InMemoryReminderRepository> _seededRepo() async {
  final repo = InMemoryReminderRepository();
  await repo.upsertList(const ReminderList(id: 'list.personal', title: '个人'));
  return repo;
}

void main() {
  testWidgets('菜单「设置…」走注入的独立窗口打开器（不再 push 应用内页面）', (tester) async {
    final calls = <VoidCallback?>[];
    final commands = await _pump(
      tester,
      repo: await _seededRepo(),
      opener: (context, {onOpenCloudLogin}) async {
        calls.add(onOpenCloudLogin);
      },
    );

    commands.value = LifeMenuAction.openSettings;
    await tester.pumpAndSettle();

    expect(calls, hasLength(1), reason: '菜单入口应交给窗口打开器');
    expect(find.text('默认列表'), findsNothing, reason: '窗口打开器可用时不得再渲染应用内设置页');
  });

  testWidgets('侧栏设置入口同样走打开器', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      repo: await _seededRepo(),
      opener: (context, {onOpenCloudLogin}) async {
        calls += 1;
      },
    );

    await tester.tap(find.byKey(const ValueKey('sidebar_settings')));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('默认列表'), findsNothing);
  });

  testWidgets('未注入打开器时回退应用内设置页', (tester) async {
    await _pump(tester, repo: await _seededRepo());

    await tester.tap(find.byKey(const ValueKey('sidebar_settings')));
    await tester.pumpAndSettle();

    expect(find.text('默认列表'), findsOneWidget, reason: '其它平台/测试宿主继续用应用内页面');
  });
}
