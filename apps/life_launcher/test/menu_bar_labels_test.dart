// TC-SHELL-368：macOS 菜单栏必须中文化并有「文件」菜单（#368）。
//
// 静态判据（不依赖 GUI）：
//  1. 壳的菜单项文案来自 `LifeMenuBar`，且含 生活台/文件/编辑/显示/窗口；
//  2. 文件菜单含「新建提醒事项」「新建备忘录」并带 ⌘N / ⌘⇧N；
//  3. 编辑菜单的撤销/剪切/拷贝/粘贴/全选指向标准 intent（不自己实现文本编辑）。
//
// 之所以用源码扫描而不是 pump：`PlatformMenuBar` 只在 macOS 引擎侧生效，
// widget 测试里不会渲染菜单栏，pump 断言等于测空气（见 #330 的教训）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/shell/life_menu_bar.dart').readAsStringSync();
  });

  test('顶层菜单中文化且含文件菜单', () {
    for (final label in ['生活台', '文件', '编辑', '显示', '窗口']) {
      expect(source.contains("label: '$label'"), isTrue,
          reason: '缺少顶层菜单「$label」——引擎默认项是英文 Edit/View/Window/Help');
    }
  });

  test('文件菜单有新建提醒 / 新建备忘录 且带快捷键', () {
    expect(source.contains("label: '新建提醒事项'"), isTrue);
    expect(source.contains("label: '新建备忘录'"), isTrue);
    expect(source.contains('LogicalKeyboardKey.keyN'), isTrue);
    expect(source.contains('shift: true'), isTrue,
        reason: '新建备忘录应有 ⇧⌘N，避免与 ⌘N 冲突');
  });

  test('#486 文件菜单有分区两项，且走命令总线不自己实现', () {
    expect(source.contains("label: '新建分区'"), isTrue,
        reason: 'Apple 文件菜单有「新建分区」');
    expect(source.contains("label: '编辑分区…'"), isTrue,
        reason: 'Apple 文件菜单有「编辑分区…」');
    expect(source.contains('LifeMenuAction.newSection'), isTrue);
    expect(source.contains('LifeMenuAction.editSections'), isTrue);
    // 菜单侧不得自己写分区逻辑：入口本体在 feature_task 的 #533 里
    expect(source.contains('upsertSection'), isFalse,
        reason: '菜单只发命令，落库由 TaskScaffold 复用 #533 的入口');
  });

  test('编辑菜单走标准 intent，不自己实现', () {
    for (final intent in [
      'UndoTextIntent',
      'RedoTextIntent',
      'CopySelectionTextIntent',
      'PasteTextIntent',
      'SelectAllTextIntent',
    ]) {
      expect(source.contains(intent), isTrue, reason: '缺少 $intent');
    }
  });

  test('壳只在 macOS 挂菜单栏（其它平台不产生多余子树）', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main.contains('TargetPlatform.macOS'), isTrue,
        reason: '要用 defaultTargetPlatform 判定（dart:io 的 Platform 在测试里是宿主平台）');
    expect(main.contains('LifeMenuBar('), isTrue);
  });
}
