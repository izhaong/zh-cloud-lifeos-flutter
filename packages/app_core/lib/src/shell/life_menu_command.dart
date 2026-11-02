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

  /// 编辑 → 将截止日期标记为…（#537）。
  markDueDate,

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
final lifeMenuCommandsProvider =
    Provider<ValueNotifier<LifeMenuAction?>?>((ref) => null);
