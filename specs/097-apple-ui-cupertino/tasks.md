# Tasks · Apple 平面风 UI 统一

状态：`[ ]` 未开始 / `[x]` 已验收。只有跑过对应验证才允许勾选。

## #128 底座 + 壳层

- [x] 工具链升 Flutter 3.47.5 / Dart 3.13.4，移除 intl/hooks 钉版（`09a89dd`）
- [x] 五个 `analysis_options.yaml` 排除构建平台目录
- [x] 五个 pubspec 加 `cupertino_ui: ^1.1.4`；删除 4 个零引用 UI 依赖
- [x] `LifeTokens.cupertino()` + `LifeTokens.materialIsland()` + `LifeMaterialIsland`
- [x] `main.dart` 换 `CupertinoApp.router`，补 Cupertino/Material delegates
- [x] 根 `ScaffoldMessenger`（过渡期）
- [x] `life_router.dart` 用 `LifeMaterialIsland` 暂包三个未迁移 App
- [x] `app_registry.dart` 图标换 `CupertinoIcons`
- [x] `life_shell.dart` compact `CupertinoTabBar`
- [x] `life_shell.dart` 宽屏 Apple 式侧栏 + 0.5px 分隔线
- [x] `more_page.dart` Cupertino 化
- [x] `placeholder_page.dart` Cupertino 化
- [x] `scripts/check_ui_boundary.dart` + melos `ui-boundary`
- [x] 边界脚本红/绿自测
- [x] `app_core` analyze 绿
- [x] `life_launcher` analyze 绿
- [x] `life_launcher` 全量 test 绿（13/13）
- [x] 另三包 analyze 绿（工具链基线）
- [x] macOS 三档截图人工验收（`docs/ui-evidence/2026-10-27-shell-{1280,1024,375}.png`）
- [x] PR 已合并进 `develop`

## #129 任务

- [x] 骨架：`Scaffold` / `AppBar` 换 Cupertino
- [x] 列表与行：`ListTile` / `Divider` / `Card` / `InkWell` 换 Cupertino
- [x] 表单：`TextField` / `DropdownButton` 换 Cupertino
- [x] 菜单与弹层：`PopupMenuButton` / `AlertDialog` / `showModalBottomSheet` 换 Cupertino
- [x] 路由：`MaterialPageRoute` 清零
- [x] `life_router.dart` 移除任务过渡岛
- [x] 受影响测试改语义 / key 断言
- [x] `feature_task` analyze/test 绿
- [ ] macOS 截图人工验收
- [x] PR 已合并进 `develop`（!140）

## #130 日历

- [x] `CalendarScaffold` / `CalendarToolbar` / `CalendarSidebar` / `EventInspectorPane` Cupertino 化
- [x] `kalender` / `table_calendar` 进 `LifeMaterialIsland`
- [ ] `cupertino_calendar_picker` 局部 SDK `CupertinoTheme`
- [x] 弹层与路由换 Cupertino
- [x] `life_router.dart` 移除日历过渡岛
- [x] 受影响测试更新（16 文件换 `lifeTestHost`，golden 暂 `skip: true`）
- [ ] golden 重录（取得授权后）
- [x] `feature_calendar` analyze/test 绿
- [ ] 三档 golden 人工比对
- [ ] PR 已合并进 `develop`

## #131 记录

- [x] `NoteScaffold` / `NoteEditorPage` / `NoteSettingsPage` / `NoteRecyclePage` / `NoteSidebar` Cupertino 化
- [x] `flutter_quill` 进 `LifeMaterialIsland`
- [x] `Drawer` / `SnackBar` / `FloatingActionButton` 换 Cupertino（Drawer→底部弹层、SnackBar→`CupertinoAlertDialog`、FAB→导航栏「新建」钮）
- [x] 路由与弹窗换 Cupertino（`CupertinoPageRoute` / `showCupertinoDialog` / `CupertinoActionSheet`）
- [x] `life_router.dart` 移除记录过渡岛；`main.dart` 移除根 `ScaffoldMessenger`
- [x] 受影响测试更新（harness 补 `GlobalCupertinoLocalizations`；`pageBack` 换显式点包内返回键——cupertino_ui 的同名 BackButton 类与 SDK 类不同源）
- [x] `feature_note` analyze/test 绿（0 issues / 25 passed）；全仓 11 包 analyze 绿；launcher 13/13 绿
- [ ] macOS 截图人工验收
- [x] 边界脚本最终白名单收口（`scanned=119 pending=0 violations=0`，`--strict` 同绿；豁免仅剩 app_core 两个主题文件）
- [ ] PR 已合并进 `develop`
