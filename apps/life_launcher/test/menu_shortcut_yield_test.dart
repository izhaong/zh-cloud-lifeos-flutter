import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/shell/life_menu_bar.dart';

/// #542：焦点在文本编辑控件里时，macOS 菜单栏不得声明与之冲突的键位。
///
/// 判什么：`PlatformMenuBar` 交给平台的那份**菜单数据**里，「删除提醒事项」的
/// `shortcut` 随焦点翻转。widget 测试里原生菜单不渲染，但这份数据会被序列化
/// （`_PlatformMenuBarState.initState → setMenus`），读它就是读「键位交没交出去」。
///
/// 真机上的键位归属（原生菜单是否真的让位、重建会不会闪）不在本文件能力内，归 #473。
final _metaBackspace = const SingleActivator(LogicalKeyboardKey.backspace, meta: true);

/// 整组都要 macOS 档位：菜单里的 `PlatformProvidedMenuItem`（about / services /
/// hide / quit / 窗口项）在别的档位上根本不存在，序列化会直接抛。
///
/// 覆盖必须在**用例体内**成对开关：binding 在 `postTest` 就断言「foundation debug
/// 变量未被测试改动」，`tearDown` 太晚——实测会把真实失败顶成一条无关断言。
Future<void> _onMacOS(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// 按 label 深度优先找菜单项（`PlatformMenu.menus` 与 `PlatformMenuItemGroup.members` 都要下钻）。
PlatformMenuItem? _findByLabel(List<PlatformMenuItem> items, String label) {
  for (final item in items) {
    final PlatformMenuItem? hit;
    if (item is PlatformMenu) {
      hit = _findByLabel(item.menus, label);
    } else if (item is PlatformMenuItemGroup) {
      hit = _findByLabel(item.members, label);
    } else if (item.label == label) {
      return item;
    } else {
      hit = null;
    }
    if (hit != null) return hit;
  }
  return null;
}

Future<ValueNotifier<LifeMenuAction?>> _pump(
  WidgetTester tester, {
  required Widget child,
}) async {
  final commands = ValueNotifier<LifeMenuAction?>(null);
  addTearDown(commands.dispose);
  await tester.pumpWidget(
    LifeMenuBar(
      commands: commands,
      child: CupertinoApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
  return commands;
}

PlatformMenuItem _deleteItem(WidgetTester tester) {
  final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
  final item = _findByLabel(bar.menus, '删除提醒事项');
  expect(item, isNotNull, reason: '菜单里没有「删除提醒事项」，判据无从谈起');
  return item!;
}

void main() {
  tearDown(() => FocusManager.instance.primaryFocus?.unfocus());

  testWidgets('焦点不在文本域 ⇒「删除提醒事项」声明 ⌘⌫', (tester) async {
    await _onMacOS(() async {
      await _pump(tester, child: const Center(child: Text('三栏')));
      expect(
        _deleteItem(tester).shortcut,
        _metaBackspace,
        reason: '不在打字时，⌘ 该归菜单（Apple「编辑 → 删除提醒事项」的键位）',
      );
    });
  });

  testWidgets('焦点在文本域 ⇒ 键位让出去（shortcut 为 null）', (tester) async {
    await _onMacOS(() async {
      await _pump(
        tester,
        child: const CupertinoTextField(key: Key('field'), autofocus: true),
      );
      expect(
        _deleteItem(tester).shortcut,
        isNull,
        reason: '原生菜单一旦注册同一个组合，按键在引擎侧就被吞掉，'
            '文本框里「⌘ 删到行首」再也收不到——这正是 #542 要防的',
      );
    });
  });

  testWidgets('跟随焦点翻转：进框让位、出框交还（不是只在首帧算一次）',
      (tester) async {
    await _onMacOS(() async {
      await _pump(tester, child: const CupertinoTextField(key: Key('field')));
      expect(_deleteItem(tester).shortcut, _metaBackspace,
          reason: '起手没焦点 ⇒ 键位归菜单');

      await tester.tap(find.byKey(const Key('field')));
      await tester.pumpAndSettle();
      expect(_deleteItem(tester).shortcut, isNull, reason: '进框 ⇒ 让位');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(_deleteItem(tester).shortcut, _metaBackspace,
          reason: '出框 ⇒ 交还菜单');
    });
  });

  testWidgets('让位只影响键位声明，不摘掉菜单项本身', (tester) async {
    await _onMacOS(() async {
      final commands = await _pump(
        tester,
        child: const CupertinoTextField(key: Key('field'), autofocus: true),
      );
      final item = _deleteItem(tester);
      expect(item.shortcut, isNull);
      item.onSelected?.call();
      expect(
        commands.value,
        LifeMenuAction.deleteReminder,
        reason: '焦点让位后，从菜单里点这一项仍要照常投命令（键位 ≠ 入口）',
      );
    });
  });

  testWidgets('文本域里 ⌘⌫ 仍是「删到行首」，不是整条清空', (tester) async {
    await _onMacOS(() async {
      final controller = TextEditingController(text: 'abcdef');
      addTearDown(controller.dispose);
      await _pump(
        tester,
        child: CupertinoTextField(
          key: const Key('field'),
          controller: controller,
          autofocus: true,
        ),
      );
      // 光标停在第 3 个字符后：删到行首应剩「def」；整删得「」，不删得「abcdef」。
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(
        controller.text,
        'def',
        reason: 'macOS 文本键位表（_macShortcuts）把 ⌘ 绑成 DeleteToLineBreakIntent；'
            '菜单让位后这条通路必须保持可用',
      );
    });
  });
}
