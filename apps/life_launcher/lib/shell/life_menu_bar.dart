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

/// #542：菜单栏的「焦点在文本域时让位」外壳。
///
/// macOS 的文本键位表（`default_text_editing_shortcuts.dart` 的 `_macShortcuts`）
/// 把「meta + backspace」绑成删除到行首。而 `PlatformMenuBar` 的 `shortcut` 是
/// **系统级**映射：原生菜单一旦声明同一个组合，按键在引擎侧就被菜单吞掉，
/// Flutter 再也收不到——于是新建/重命名弹层里「输入到一半想删到行首」会变成
/// 「整条提醒被删」。
///
/// 这个外壳只做一件事：盯住焦点，**翻转时**才重建菜单（不翻转不重建，
/// 原生菜单跟着重建有代价；真实闪烁仍归 #473 真人走查）。
class LifeMenuBar extends StatefulWidget {
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
  State<LifeMenuBar> createState() => _LifeMenuBarState();
}

class _LifeMenuBarState extends State<LifeMenuBar> {
  bool _editingText = _focusIsTextInput();

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    final next = _focusIsTextInput();
    if (next == _editingText) return;
    setState(() => _editingText = next);
  }

  /// 焦点节点建在 `EditableText` 内部（`TextField` / `CupertinoTextField` 都是），
  /// 所以从它的 context 往上找一层就能判定「现在是不是在打字」。
  static bool _focusIsTextInput() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) => _LifeMenuBarBody(
    editingText: _editingText,
    commands: widget.commands,
    onAbout: widget.onAbout,
    child: widget.child,
  );
}

class _LifeMenuBarBody extends StatelessWidget {
  const _LifeMenuBarBody({
    required this.editingText,
    required this.child,
    required this.commands,
    required this.onAbout,
  });

  /// true ⇒ 焦点在文本编辑控件里，冲突键位让给文本编辑（#542）。
  final bool editingText;

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
                  onSelected: () =>
                      commands.value = LifeMenuAction.openSettings,
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
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                meta: true,
              ),
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
            // #537：Apple「文件 → 编辑列表」作用于前台清单。弹层本体复用
            // feature_task 里侧栏 ⋯ 用的那一个，不在菜单侧做第二套选择器。
            PlatformMenuItem(
              label: '编辑列表',
              onSelected: () => commands.value = LifeMenuAction.editList,
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
            // flutter #567：Apple「文件 ▸ 用所选项目新建分区」= ⌃⌘N。
            // 与「移至分区…」同律：壳里判不了选中，只投命令，
            // 未选中时由 feature_task 给可见提示且不写数据。
            PlatformMenuItem(
              label: '用所选项目新建分区',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                control: true,
                meta: true,
              ),
              onSelected: () =>
                  commands.value = LifeMenuAction.createSectionFromSelection,
            ),
            // #537：Apple「文件 → 移至分区…」。操作对象是三栏里当前选中的
            // 条目，选中态与写回都在 feature_task；菜单侧判不了选中，也不许
            // 自己存一份选择。
            PlatformMenuItem(
              label: '移至分区…',
              onSelected: () => commands.value = LifeMenuAction.moveToSection,
            ),
            // #537：Apple「Pin Sublist / Unpin Sublist」。置顶态是前台列表的
            // 属性，壳里判不了「当前是哪一条」，也只投命令；两份视图态一律落在
            // feature_task。不挂键位（同 #542）。
            PlatformMenuItem(
              label: '置顶列表',
              onSelected: () => commands.value = LifeMenuAction.pinList,
            ),
            PlatformMenuItem(
              label: '取消置顶列表',
              onSelected: () => commands.value = LifeMenuAction.unpinList,
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
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                  ),
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
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyX,
                    meta: true,
                  ),
                  onSelected: () => _invoke(
                    const CopySelectionTextIntent.cut(
                      SelectionChangedCause.keyboard,
                    ),
                  ),
                ),
                PlatformMenuItem(
                  label: '拷贝',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyC,
                    meta: true,
                  ),
                  onSelected: () => _invoke(CopySelectionTextIntent.copy),
                ),
                PlatformMenuItem(
                  label: '粘贴',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyV,
                    meta: true,
                  ),
                  onSelected: () => _invoke(
                    const PasteTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
                PlatformMenuItem(
                  label: '全选',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyA,
                    meta: true,
                  ),
                  onSelected: () => _invoke(
                    const SelectAllTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
              ],
            ),
            // #537：Apple「编辑 → 删除提醒事项」。删除对象是三栏里当前
            // 选中的条目，选中态、落库与回收窗都在 feature_task；菜单侧只投
            // 命令，判不了选中，也不许自己碰仓库。
            //
            // #542：这一项的 ⌘ 现在挂得上了——上面那层外壳会在焦点落进文本
            // 编辑控件时把 shortcut 摘掉，离开文本域再交还给原生菜单。
            // 键位语义与 Apple 一致（⌘ 删除当前选中条目），行为仍只投命令。
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: '删除提醒事项',
                  shortcut: editingText
                      ? null
                      : const SingleActivator(
                          LogicalKeyboardKey.backspace,
                          meta: true,
                        ),
                  onSelected: () =>
                      commands.value = LifeMenuAction.deleteReminder,
                ),
              ],
            ),
            // #537：Apple「编辑 → 缩进 / 减少缩进」。层级由 feature_task 侧
            // 那条提醒事项的父级字段承载（空值 = 顶层），菜单侧只投命令；
            // 「上一条是谁」要按真实渲染行序算，菜单这一层判不了布局。
            // 这一组刻意不声明键位：Apple 用 ⌘] / ⌘[，而 #542 那套让位机制
            // 只解决「与文本编辑抢键」，键位该不该占是另一个决定，留给后续卡。
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: '缩进',
                  onSelected: () =>
                      commands.value = LifeMenuAction.indentReminder,
                ),
                PlatformMenuItem(
                  label: '减少缩进',
                  onSelected: () =>
                      commands.value = LifeMenuAction.outdentReminder,
                ),
              ],
            ),
            // #537：Apple「编辑 → 查找…」。聚焦搜索框这件事键盘侧已经有了
            // （feature_task 的 TaskShortcuts 把 meta+F 绑成 requestFocusSearch），
            // 这里只补菜单入口、走同一个票据，不另写第二套聚焦逻辑。
            // 菜单也不声明 ⌘F：同一个键位有两处入口后，原生菜单会先吞掉按键，
            // Flutter 侧的 Shortcuts 就再也收不到 —— 键位统一归 Issue #542 处理。
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: '查找…',
                  onSelected: () =>
                      commands.value = LifeMenuAction.findReminder,
                ),
                PlatformMenuItem(
                  label: '替换…',
                  onSelected: () =>
                      commands.value = LifeMenuAction.replaceText,
                ),
              ],
            ),
            // #537：Apple「编辑 → 将截止日期标记为…」。档位与落库都在
            // feature_task（今天视图拖档那一份实现），菜单侧不定义「今晚是几点」，
            // 也不挂键位（同 #542）。
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: '将截止日期标记为…',
                  onSelected: () => commands.value = LifeMenuAction.markDueDate,
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
              onSelected: () =>
                  commands.value = LifeMenuAction.toggleSmartLists,
            ),
            PlatformMenuItem(
              label: '显示边栏',
              onSelected: () => commands.value = LifeMenuAction.toggleSidebar,
            ),
            PlatformMenuItem(
              label: '隐藏完成项目',
              onSelected: () => commands.value = LifeMenuAction.toggleCompleted,
            ),
            PlatformMenuItem(
              label: '根据时间分组',
              onSelected: () =>
                  commands.value = LifeMenuAction.toggleGroupByTime,
            ),
            PlatformMenuItem(
              label: '显示所有子任务',
              onSelected: () => commands.value = LifeMenuAction.showAllSubtasks,
            ),
            PlatformMenuItem(
              label: '隐藏所有子任务',
              onSelected: () => commands.value = LifeMenuAction.hideSubtasks,
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
                  onSelected: () => commands.value = LifeMenuAction.sortByTitle,
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
