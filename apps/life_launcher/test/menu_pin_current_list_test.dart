import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/main.dart';
import 'package:life_launcher/shell/pinned_tabs_service.dart';
import 'package:life_launcher/shell_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// #585：真机走查发现的「文件 → 置顶列表」误报。
///
/// 现象（真人路径：侧栏点用户清单 → 原生菜单「置顶列表」）：界面弹
/// 「智能清单不用置顶」，而清单的 `is_pinned` 仍是 false。
///
/// 本文件把这条路径压成壳层用例：点侧栏行改前台清单，再打同一张菜单票据
/// （`lifeMenuCommandsProvider` 那个 `ValueNotifier`，与原生菜单写的是同一个），
/// 断言仓储里那条清单真的被置顶。
void main() {
  final fixed = DateTime(2026, 10, 26, 9, 30);

  Future<(InMemoryReminderRepository, ValueNotifier<LifeMenuAction?>)> pumpShell(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final repo = InMemoryReminderRepository()..nowForTest = fixed;
    await repo.upsertList(
      const ReminderList(id: 'list.grocery', title: '日常采购', sortOrder: 0),
    );
    final commands = ValueNotifier<LifeMenuAction?>(null);
    addTearDown(commands.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          pinnedTabsServiceProvider.overrideWithValue(PinnedTabsService(prefs)),
          clockProvider.overrideWithValue(() => fixed),
          lifeMenuCommandsProvider.overrideWithValue(commands),
        ],
        child: const LifeLauncherApp(),
      ),
    );
    await tester.pumpAndSettle();
    return (repo, commands);
  }

  Future<ReminderList> readList(InMemoryReminderRepository repo, String id) async {
    final lists = await repo.watchLists().first;
    return lists.firstWhere((e) => e.id == id);
  }

  testWidgets('点侧栏行选中用户清单后，「置顶列表」写的是这条清单（#585）', (tester) async {
    final (repo, commands) = await pumpShell(tester);

    // 真人路径第 1 步：侧栏点「日常采购」，详情栏当场切过去。
    await tester.tap(find.byKey(const ValueKey('my_list_list.grocery')));
    await tester.pumpAndSettle();
    expect(find.text('日常采购'), findsWidgets, reason: '没点进清单，后面的一切都不成立');

    // 真人路径第 2 步：原生菜单「文件 → 置顶列表」= 往同一张票据上写动作。
    commands.value = LifeMenuAction.pinList;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('智能清单不用置顶'),
      findsNothing,
      reason: '#585 现象：用户清单被当成智能清单拒绝',
    );
    final grocery = await readList(repo, 'list.grocery');
    expect(
      grocery.isPinned,
      isTrue,
      reason: '#585 判据：置顶要落到这条清单自己身上（is_pinned=true）',
    );
  });

  testWidgets('前台是智能清单「今天」时仍然拒绝置顶（闸门不许拆）', (tester) async {
    final (repo, commands) = await pumpShell(tester);

    // 宽屏档默认就落在「今天」，不点任何用户清单。
    commands.value = LifeMenuAction.pinList;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('智能清单不用置顶'),
      findsOneWidget,
      reason: '智能清单不该被置顶——这条拒绝是既有正确行为',
    );
    final lists = await repo.watchLists().first;
    expect(
      lists.where((e) => e.isPinned),
      isEmpty,
      reason: '拒绝路径不许顺手写库',
    );
  });
}
