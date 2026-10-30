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

  /// 应用菜单 → 设置…（#486）。
  openSettings,

  /// 显示 → 显示/隐藏智能列表（#486）。
  toggleSmartLists,

  /// 显示 → 显示/隐藏边栏（#486）。
  toggleSidebar,

  /// 显示 → 隐藏/显示已完成项目（#486）。
  toggleCompleted,
}

/// 命令出口。**没有菜单栏的平台（非 macOS）为 null**，页面订阅时必须判空。
///
/// 约定：接收方消费后要把值清回 `null`（`notifier.value = null`），
/// 否则同一条命令会在下次重建/重新挂载时被重复执行。
final lifeMenuCommandsProvider =
    Provider<ValueNotifier<LifeMenuAction?>?>((ref) => null);
