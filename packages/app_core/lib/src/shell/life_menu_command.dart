// 菜单命令总线（#375）。
//
// macOS 菜单栏由 `PlatformMenuBar` 在 `CupertinoApp` **之上**构建（#368），
// 因此它拿不到页面层的 BuildContext，只能用一条命令总线把「用户点了哪个菜单项」
// 传下去：组合根持有 [ValueNotifier]，页面自己订阅。
//
// 放在 app_core 而不是某个 feature 里：命令的**发送方**是壳（app），
// **接收方**可能来自任何一个 feature，放在共享层才不会让 feature 互相 import。
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 菜单栏可以发起的命令。
enum LifeMenuAction {
  /// 文件 → 新建提醒事项（⌘N）。
  newReminder,

  /// 文件 → 新建备忘录（⇧⌘N）。
  newNote,

  /// 文件 → 新建列表（#486）。
  newList,

  /// 文件 → 新建分区（#486；接 #533 的入口，仅非智能清单生效）。
  newSection,

  /// 文件 → 用所选项目新建分区（⌃⌘N，对等矩阵行 37 / flutter #567）。
  ///
  /// 与 [moveToSection] 同一条不变量：**菜单侧不判选中、也不另存一份选择**
  /// （#537 写在 life_menu_bar 的注释里）。选中态只有 feature_task 有，
  /// 未选中时由它给可见提示并且**一字不写**。
  createSectionFromSelection,

  /// 文件 → 编辑列表（#537；编辑**当前前台清单**，智能清单不可用）。
  editList,

  /// 文件 → 编辑分区…（#486；同上）。
  editSections,

  /// 应用菜单 → 设置…（#486）。
  openSettings,

  /// 显示 → 显示/隐藏智能列表（#486）。
  toggleSmartLists,

  /// 显示 → 显示/隐藏边栏（#486）。
  toggleSidebar,

  /// 显示 → 根据时间分组（#574）。仅影响「全部」智能列表的分组口径。
  toggleGroupByTime,

  /// 显示 → 列表视图（#573）：关掉 expanded 的第三栏，详情走锚定弹窗。
  viewModeList,

  /// 显示 → 分栏视图（#573）：恢复侧栏 + 列表 + 详情第三栏。

  /// 显示 → 分区列排（#602）：每个分区一条横向列（矩阵行 41）。
  /// 与上面 `viewModeColumns`（窗格第三栏）无关，名字刻意错开。
  toggleSectionColumns,
  viewModeColumns,

  /// 显示 → 隐藏/显示已完成项目（#486）。
  toggleCompleted,

  /// 显示 → 排序方式 → 手动（#537；与工具栏「排序 ▾」同档，不是第二套排序）。
  sortByManual,

  /// 显示 → 排序方式 → 按到期日（#537）。
  sortByDueDate,

  /// 显示 → 排序方式 → 按创建日期（#537）。
  sortByCreatedDate,

  /// 显示 → 排序方式 → 按标题（#537）。
  sortByTitle,

  /// 显示 → 排序方式 → 按优先级（#537）。
  sortByPriority,

  /// 显示 → 显示所有子任务（#537）。
  showAllSubtasks,

  /// 显示 → 隐藏所有子任务（#537）。
  hideSubtasks,

  /// 文件 → 移至分区…（#537）。
  moveToSection,

  /// 编辑 → 删除提醒事项（#537）。
  deleteReminder,

  /// 编辑 → 查找…（#537）。
  findReminder,

  /// 编辑 → 替换…（#576）：对当前选中条目的标题/备注做查找替换。
  replaceText,

  /// 编辑 → 将截止日期标记为…（#537）。
  markDueDate,

  /// 文件 → 打印…（#572）：把当前前台清单导出 PDF 并打开系统打印面板。
  printList,

  /// 文件 → 置顶列表（#537）。
  pinList,

  /// 文件 → 取消置顶列表（#537）。
  unpinList,

  /// 编辑 → 缩进（#537）。挂到**屏幕上紧挨着它的上一条**下面。
  indentReminder,

  /// 编辑 → 减少缩进（#537）。回到上一层（父的父），顶层条目不再往外减。
  outdentReminder,
}

/// 命令出口。**没有菜单栏的平台（非 macOS）为 null**，页面订阅时必须判空。
///
/// 约定：接收方消费后要把值清回 `null`（`notifier.value = null`），
/// 否则同一条命令会在下次重建/重新挂载时被重复执行。
final lifeMenuCommandsProvider = Provider<ValueNotifier<LifeMenuAction?>?>(
  (ref) => null,
);


/// 「显示 → 前往」的清单条目（#575）。壳只负责渲染，清单数据由 feature_task 发布。
final class LifeMenuGoToTarget {
  const LifeMenuGoToTarget({required this.id, required this.title});

  final String id;
  final String title;
}

/// 清单快照出口：feature_task 把当前可见清单写进来，菜单栏监听重建「前往」子菜单。
final lifeMenuGoToListsProvider =
    Provider<ValueNotifier<List<LifeMenuGoToTarget>>?>((ref) => null);

/// 「前往」点击出口：菜单写清单 id，feature_task 消费后切到该列表并清零。
final lifeMenuGoToRequestProvider =
    Provider<ValueNotifier<String?>?>((ref) => null);
