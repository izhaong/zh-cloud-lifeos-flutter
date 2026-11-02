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

  test('#537 显示菜单挂「排序方式」五项，且菜单侧不实现排序', () {
    expect(source.contains("label: '排序方式'"), isTrue,
        reason: 'Apple「显示 → 排序方式」是子菜单');
    for (final label in ['手动', '按到期日', '按创建日期', '按标题', '按优先级']) {
      expect(source.contains("label: '$label'"), isTrue,
          reason: '排序方式子菜单缺少「$label」');
    }
    for (final a in [
      'sortByManual',
      'sortByDueDate',
      'sortByCreatedDate',
      'sortByTitle',
      'sortByPriority',
    ]) {
      expect(source.contains('LifeMenuAction.$a'), isTrue,
          reason: '菜单未指向 $a');
    }
    // 排序写入只能在 feature_task 的 provider 里；壳里出现这个名字就说明有人
    // 把第二套排序搬进了菜单层。（判据刻意不用类型名——说明性注释里会出现它。）
    expect(source.contains('listSortModeProvider'), isFalse,
        reason: '壳不得自己实现排序');
    expect(source.contains('.notifier.set('), isFalse,
        reason: '壳不得直接写偏好');
  });

  test('#537 文件菜单有「编辑列表」，且弹层不在壳里自己实现', () {
    expect(source.contains("label: '编辑列表'"), isTrue,
        reason: 'Apple 文件菜单有「编辑列表」');
    expect(source.contains('LifeMenuAction.editList'), isTrue,
        reason: '菜单项必须指向命令总线的 editList');
    // 编辑弹层本体在 feature_task（侧栏 ⋯ 用的同一个）；壳里出现这些名字
    // 就说明有人复制了第二套实现。
    expect(source.contains('showEditListDialog'), isFalse,
        reason: '壳不得自己实现列表编辑');
    expect(source.contains('upsertList'), isFalse, reason: '壳不得直接落库');
  });

  test('#537 显示菜单有子任务显隐两项，且开关不落在壳里', () {
    expect(source.contains("label: '显示所有子任务'"), isTrue);
    expect(source.contains("label: '隐藏所有子任务'"), isTrue);
    expect(source.contains('LifeMenuAction.showAllSubtasks'), isTrue);
    expect(source.contains('LifeMenuAction.hideSubtasks'), isTrue);
    // 子任务显隐是 feature_task 的视图态；壳里出现这些就说明有人把状态搬进菜单层。
    expect(source.contains('collapsedKeys'), isFalse,
        reason: '壳不得自己存视图态');
    expect(source.contains('parentId'), isFalse,
        reason: '壳不得自己过滤子任务');
  });

  test('#537 文件菜单有「移至分区…」，且选择器与写回不在壳里', () {
    expect(source.contains("label: '移至分区…'"), isTrue,
        reason: 'Apple 文件菜单有「移至分区…」');
    expect(source.contains('LifeMenuAction.moveToSection'), isTrue,
        reason: '菜单项必须指向命令总线的 moveToSection');
    // 分区选择器与条目写回都在 feature_task（那里才有选中态）；
    // 壳里出现这些名字就说明有人另写了一套。
    expect(source.contains('CupertinoActionSheet'), isFalse,
        reason: '壳不得自己实现分区选择器');
    expect(source.contains('upsertItem'), isFalse, reason: '壳不得直接落库');
  });

  test('#537 编辑菜单有「删除提醒事项」，且删除不落在壳里', () {
    expect(source.contains("label: '删除提醒事项'"), isTrue,
        reason: 'Apple 编辑菜单有 Delete Reminder');
    expect(source.contains('LifeMenuAction.deleteReminder'), isTrue,
        reason: '菜单项必须指向命令总线的 deleteReminder');
    // 删除语义（软删 + 30 天回收窗 + 父删子随）全在 feature_task 的既有契约里。
    expect(source.contains('deleteItem'), isFalse, reason: '壳不得自己删数据');
    expect(source.contains('restoreItem'), isFalse, reason: '壳不得自己恢复');
  });

  test('#537 编辑菜单有「查找…」，且菜单不抢 ⌘F/⌘⌫ 键位', () {
    expect(source.contains("label: '查找…'"), isTrue,
        reason: 'Apple 编辑菜单有 Find…');
    expect(source.contains('LifeMenuAction.findReminder'), isTrue,
        reason: '菜单项必须指向命令总线的 findReminder');
    // ⌘F 归 feature_task 的 TaskShortcuts；⌘⌫ 与文本框删到行首冲突。
    // 两个键位都不许在壳里各声明一份（前置见 flutter Issue #542）。
    expect(source.contains('LogicalKeyboardKey.keyF'), isFalse,
        reason: '菜单不得抢 ⌘F，否则 Flutter 侧 Shortcuts 收不到');
    expect(source.contains('LogicalKeyboardKey.delete'), isFalse,
        reason: '菜单不得抢 ⌘⌫，文本框里它已绑删除到行首');
    expect(source.contains('searchQueryProvider'), isFalse,
        reason: '壳不得自己实现搜索');
  });

  test('#537 编辑菜单有「将截止日期标记为…」，且档位定义不在壳里', () {
    expect(source.contains("label: '将截止日期标记为…'"), isTrue,
        reason: 'Apple 编辑菜单有 Mark 日期档');
    expect(source.contains('LifeMenuAction.markDueDate'), isTrue,
        reason: '菜单项必须指向命令总线的 markDueDate');
    // 「上午/下午/今晚/今天」几点落地，是 feature_task 拖档那一份实现（_sectionTime）
    // 的事；壳里出现这些名字就说明有人复制了第二套日期定义。
    expect(source.contains('_sectionTime'), isFalse,
        reason: '壳不得自己定义档位的时刻');
    expect(source.contains('_onSectionDrop'), isFalse,
        reason: '壳不得自己写日期落库');
    expect(source.contains('dueAt'), isFalse, reason: '壳不得自己碰日期字段');
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
