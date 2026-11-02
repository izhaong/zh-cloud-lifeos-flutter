// macOS 菜单栏（#368）。
//
// 由来：壳里从未设置 `PlatformMenuBar`，于是 macOS 顶部菜单由引擎默认项给出——
// 英文 `Edit / View / Window / Help`，且**没有「文件」菜单**（Apple 三应用都有）。
// 这里用 Dart 侧菜单整体接管：中文文案 + 文件/编辑/显示/帮助 结构。
//
// 只在 macOS 生效：`PlatformMenuBar` 在其它平台是透明包装（子组件原样返回），
// 但为免在 Web/移动端产生无谓子树，调用方只在 `Platform.isMacOS` 时包一层。
// 这是**平台能力差异**，不是布局按平台分叉（铁律 §8 禁的是后者）。
import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class LifeMenuBar extends StatelessWidget {
  const LifeMenuBar({
    super.key,
    required this.child,
    required this.commands,
    this.onAbout,
  });

  final Widget child;

  /// 命令出口：菜单项被选中时写入，页面侧监听并执行。
  final ValueNotifier<LifeMenuAction?> commands;

  /// 「关于生活台」；为空时用系统 about 面板。
  final VoidCallback? onAbout;

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: <PlatformMenuItem>[
        PlatformMenu(
          label: '生活台',
          menus: <PlatformMenuItem>[
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                if (onAbout != null)
                  PlatformMenuItem(label: '关于生活台', onSelected: onAbout)
                else
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.about,
                  ),
                PlatformMenuItem(
                  label: '设置…',
                  onSelected: () => commands.value = LifeMenuAction.openSettings,
                ),
                const PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.servicesSubmenu,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hideOtherApplications,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.showAllApplications,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: '文件',
          menus: <PlatformMenuItem>[
            PlatformMenuItem(
              label: '新建提醒事项',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
              onSelected: () => commands.value = LifeMenuAction.newReminder,
            ),
            PlatformMenuItem(
              label: '新建备忘录',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                meta: true,
                shift: true,
              ),
              onSelected: () => commands.value = LifeMenuAction.newNote,
            ),
            PlatformMenuItem(
              label: '新建列表',
              onSelected: () => commands.value = LifeMenuAction.newList,
            ),
            // #486：分区入口本体在 #533 已落地（⋯ 菜单），这里只接线——
            // 命令由 TaskScaffold 消费并复用同一对弹层，菜单侧不另写新建逻辑。
            PlatformMenuItem(
              label: '新建分区',
              onSelected: () => commands.value = LifeMenuAction.newSection,
            ),
            PlatformMenuItem(
              label: '编辑分区…',
              onSelected: () => commands.value = LifeMenuAction.editSections,
            ),
          ],
        ),
        PlatformMenu(
          label: '编辑',
          menus: <PlatformMenuItem>[
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: '撤销',
                  shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
                  onSelected: () => _invoke(
                    const UndoTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
                PlatformMenuItem(
                  label: '重做',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                    shift: true,
                  ),
                  onSelected: () => _invoke(
                    const RedoTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: '剪切',
                  shortcut: const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
                  onSelected: () => _invoke(
                    const CopySelectionTextIntent.cut(
                      SelectionChangedCause.keyboard,
                    ),
                  ),
                ),
                PlatformMenuItem(
                  label: '拷贝',
                  shortcut: const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
                  onSelected: () => _invoke(CopySelectionTextIntent.copy),
                ),
                PlatformMenuItem(
                  label: '粘贴',
                  shortcut: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
                  onSelected: () => _invoke(
                    const PasteTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
                PlatformMenuItem(
                  label: '全选',
                  shortcut: const SingleActivator(LogicalKeyboardKey.keyA, meta: true),
                  onSelected: () => _invoke(
                    const SelectAllTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: '显示',
          menus: <PlatformMenuItem>[
            PlatformMenuItem(
              label: '显示智能列表',
              onSelected: () => commands.value = LifeMenuAction.toggleSmartLists,
            ),
            PlatformMenuItem(
              label: '显示边栏',
              onSelected: () => commands.value = LifeMenuAction.toggleSidebar,
            ),
            PlatformMenuItem(
              label: '隐藏完成项目',
              onSelected: () => commands.value = LifeMenuAction.toggleCompleted,
            ),
            // #537：Apple「显示 → 排序方式」。排序能力本体在 feature_task
            // （工具栏「排序 ▾」用的同一份模式与 provider），这里只挂同义菜单，
            // 不新造第二套排序——判据见 menu_bar_labels_test.dart。
            PlatformMenu(
              label: '排序方式',
              menus: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: '手动',
                  onSelected: () =>
                      commands.value = LifeMenuAction.sortByManual,
                ),
                PlatformMenuItem(
                  label: '按到期日',
                  onSelected: () =>
                      commands.value = LifeMenuAction.sortByDueDate,
                ),
                PlatformMenuItem(
                  label: '按创建日期',
                  onSelected: () =>
                      commands.value = LifeMenuAction.sortByCreatedDate,
                ),
                PlatformMenuItem(
                  label: '按标题',
                  onSelected: () =>
                      commands.value = LifeMenuAction.sortByTitle,
                ),
                PlatformMenuItem(
                  label: '按优先级',
                  onSelected: () =>
                      commands.value = LifeMenuAction.sortByPriority,
                ),
              ],
            ),
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),
        const PlatformMenu(
          label: '窗口',
          menus: <PlatformMenuItem>[
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.minimizeWindow,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.zoomWindow,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.arrangeWindowsInFront,
                ),
              ],
            ),
          ],
        ),
      ],
      child: child,
    );
  }

  /// 把标准文本编辑 intent 投给当前焦点（菜单栏自身没有可用的 BuildContext）。
  void _invoke(Intent intent) {
    final target = FocusManager.instance.primaryFocus?.context;
    if (target == null) {
      return;
    }
    Actions.maybeInvoke(target, intent);
  }
}
