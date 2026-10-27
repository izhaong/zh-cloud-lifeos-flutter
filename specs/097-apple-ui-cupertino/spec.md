# Apple 平面风 UI 统一（cupertino_ui）

- 状态：Accepted（2026-10-27）
- Epic：`#127`
- 子任务：`#128` 底座 + 壳层 / `#129` 任务 / `#130` 日历 / `#131` 记录
- 目标仓：`zh-cloud-lifeos-flutter`，集成线 `develop`

## 1. 问题

四个 UI 面各长各的：

| 面 | 现状 |
|----|------|
| 壳层 `apps/life_launcher` | Material 3 `NavigationRail` / `NavigationBar`（飞书式） |
| `feature_task` | Cupertino 图标 + 自建 `ReminderTokens`，但骨架仍是 Material `Scaffold` / `AppBar` / `ListTile` |
| `feature_calendar` | `kalender` + `table_calendar`（Material）混 `cupertino_calendar_picker` |
| `feature_note` | Material `AppBar` + `flutter_quill` |

`app_core` 的 `LifeTokens` 只有 3 个颜色 + Material 3 seed，未承担统一职责。37/60 个 lib Dart 文件 import `package:flutter/material.dart`。

## 2. 目标与非目标

### 目标

1. 四个 UI 面统一到 `cupertino_ui` 的 Apple 平面风；除显式 Material 岛外，自有 UI 不出现 Material 组件。
2. 壳层在 compact 用 `CupertinoTabBar`、宽屏用 Apple 式侧栏；三个 App 的页面骨架、按钮、表单、弹层全部 Cupertino。
3. 保留现有信息架构、路由、数据层与 `ReminderTokens`，不新建组件库、不新增令牌抽象层。
4. 每个包 `dart analyze --fatal-infos` + 全量 `flutter test` 绿。

### 非目标

- 不做 iOS 26 Liquid Glass。
- 不替换 `kalender` / `flutter_quill` 内核（它们是显式 Material 岛）。
- 不在本 Epic 补功能缺口（按各 App 对等矩阵另开线）。
- 不在本 Epic 继续升级 Flutter（3.47.5 是 #128 的工具链基线，不再往上跳）。

## 3. 选型决策

**统一依赖：`cupertino_ui: ^1.1.4`；工具链基线 Flutter 3.47.5 / Dart 3.13.4。**

证据（2026-10-27 实测）：

1. `go_router 18.1.1` 已直接依赖 `cupertino_ui ^1.0.0` 与 `material_ui ^1.0.0`；加直接依赖不新增包。
2. `go_router` 的 `isCupertinoApp()` 认 `cupertino_ui` 包的 `CupertinoApp`。若根用 SDK 自带 `CupertinoApp`，go_router 会落到 `NoTransitionPage`，页面转场消失。
3. `cupertino_ui 1.1.0` 已被 pub 撤回；`1.1.1+` 要求 Flutter >= 3.47。本机与仓库工具链已升到 Flutter 3.47.5 / Dart 3.13.4（#128 的 `09a89dd`，移除 `intl` / `hooks` 钉版），因此直接使用 `1.1.4`。
4. 本地探针已验证：`cupertino_ui` + SDK Material 岛 + `GlobalMaterialLocalizations` 可编译、测试通过；3.47.5 下四个包 analyze 绿。

### 3.1 交叉评审记录

- **cursor-agent**：参与。支持 `cupertino_ui` 方向，并指出三个真实断点——弃用桥不能冒充完整 `ThemeData`、`CupertinoApp` 缺 `ScaffoldMessenger` / `GlobalMaterialLocalizations`、残留 `MaterialPageRoute` / `showModalBottomSheet` 与 Cupertino 返回手势冲突。本 spec 的「显式 Material 岛 + 根 ScaffoldMessenger + 各 App PR 清零 Material 路由」按这三条落地。
- **claude CLI**：两次（本会话与并行会话）均 0 字节输出、20+ 分钟无结论，已停止。按长目标提示词 F.10 降级为本地独立评审（只读对照设计稿 + 父仓规则）并继续，额度恢复后可对争议点补一轮。

否掉的替代：

- **SDK `flutter/cupertino.dart` 根**：go_router 不识别，页面转场退化为 `NoTransitionPage`。
- **`liquid_glass_widgets`**：只提供玻璃容器，没有日期选择/分段控件/表单/列表；且现有参考图为平面风。
- **`macos_ui`**：只保 macOS，iPhone/iPad 无法复用。

## 4. 架构

### 4.1 根

`apps/life_launcher/lib/main.dart`：

- `MaterialApp.router` → `CupertinoApp.router`（`package:cupertino_ui/cupertino_ui.dart`）。
- `theme: LifeTokens.cupertino()`。
- 本地化 delegates：`GlobalCupertinoLocalizations`（`cupertino_ui`）+ `GlobalWidgetsLocalizations` + `GlobalMaterialLocalizations`（SDK，供 Material 岛）。
- 根 `builder` 提供 `ScaffoldMessenger`（SDK Material），保证未迁移的 App 在过渡期仍能弹 `SnackBar`；全部 App 迁移完成后移除。

### 4.2 主题

`packages/app_core/lib/src/theme/life_tokens.dart`：

- 保留现有 `brand` / `surface` / `onSurface`。
- 新增 `LifeTokens.cupertino()`：`CupertinoThemeData`（`primaryColor: brand`、`scaffoldBackgroundColor: surface`、`barBackgroundColor`）。
- `LifeTokens.light()` 改名为 `LifeTokens.materialIsland()`，只服务 Material 岛。

### 4.3 Material 岛

`packages/app_core/lib/src/theme/life_material_island.dart`：

```dart
Theme(
  data: LifeTokens.materialIsland(),
  child: Material(type: MaterialType.transparency, child: child),
)
```

- 只允许两处第三方内核进入：`feature_calendar` 的 `kalender` / `table_calendar`，`feature_note` 的 `flutter_quill`。
- `cupertino_calendar_picker` 不依赖 Material，用 SDK `CupertinoTheme` 局部包一层继承色板。
- 不使用 `CupertinoUiCompatibilityBridge`（1.0.2 已弃用，撞 `--fatal-infos`）。

### 4.4 边界门禁

新增 `scripts/check_ui_boundary.dart`：

- 扫描四个 UI 包的 `lib/**/*.dart`，`package:flutter/material.dart` 只允许出现在白名单文件。
- 白名单必须写原因与移除条件；`#128` 阶段允许 `main.dart`、`life_router.dart`、`life_tokens.dart` 与未迁移 App 的文件；`#131` 收口后只剩两个内核文件 + `life_tokens.dart`。
- 加入根 `pubspec.yaml` 的 melos 脚本 `ui-boundary`。

## 5. 逐面改造清单

### 5.1 壳层（`#128`）

- compact：`CupertinoTabBar` 替代 `NavigationBar`。
- 宽屏：固定宽侧栏（`CupertinoListTile` + 0.5px `CupertinoColors.separator`）替代 `NavigationRail`。
- 选中态：圆角矩形底色（`CupertinoColors.systemBlue` 12% 或 `tertiarySystemFill`）。
- `MorePage`：`CupertinoPageScaffold` + `CupertinoNavigationBar` + `CupertinoListSection` / `CupertinoListTile`；`SnackBar` 换 `showCupertinoDialog`。
- `PlaceholderPage`：`CupertinoPageScaffold` + `CupertinoNavigationBar`。
- 徽标：本地 `_Badge` widget（红底白字圆形），替代 Material `Badge.count`。
- 应用图标：`CupertinoIcons`。

### 5.2 任务（`#129`）

- `Scaffold` → `CupertinoPageScaffold`；`AppBar` → `CupertinoNavigationBar` / `CupertinoSliverNavigationBar`。
- `ListTile` → `CupertinoListTile`；`TextButton` / `IconButton` → `CupertinoButton`。
- `TextField` → `CupertinoTextField`；`DropdownButton` → `CupertinoActionSheet` / `CupertinoSlidingSegmentedControl`。
- `PopupMenuButton` → `CupertinoContextMenu` / `CupertinoMenuAnchor`。
- `AlertDialog` → `CupertinoAlertDialog`；`showDialog` → `showCupertinoDialog`；`showModalBottomSheet` → `CupertinoSheetRoute`。
- `Card` → `Container` + Cupertino 表面色；`InkWell` → `GestureDetector` + `CupertinoFocusHalo`；`Divider` → 0.5px 分隔线。
- 保留 `ReminderTokens`。

### 5.3 日历（`#130`）

- `CalendarScaffold` / `CalendarToolbar` / `CalendarSidebar` / `EventInspectorPane` / 设置页外壳换 Cupertino。
- `kalender` 与 `table_calendar` 包进 `LifeMaterialIsland`；事件 tile 的配色/字体按 Cupertino 主题传入。
- `cupertino_calendar_picker` 用 SDK `CupertinoTheme` 局部包裹。
- `MaterialPageRoute` / `showDialog` / `showModalBottomSheet` 换 Cupertino。
- 重录 3 张 golden；执行前单独取得用户授权。

### 5.4 记录（`#131`）

- `NoteScaffold` / `NoteEditorPage` / `NoteSettingsPage` / `NoteRecyclePage` / `NoteSidebar` 外壳换 Cupertino。
- `flutter_quill` 包进 `LifeMaterialIsland`；工具栏按 Cupertino 色板收口。
- `Drawer` → Cupertino 侧滑 / `CupertinoSheetRoute`；`SnackBar` → Cupertino 提示；`FloatingActionButton` → 导航栏动作或浮动 Cupertino 按钮。
- `MaterialPageRoute` / `showDialog` 换 Cupertino。

## 6. 测试与验收

每个包：

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd packages/<pkg> && flutter analyze --fatal-infos && flutter test
```

- `apps/life_launcher`：壳层三档截图（375 / 1024 / 1280），选中态、分隔线、徽标、更多页编辑态。
- 测试宿主可继续用 SDK `MaterialApp`；依赖 `CupertinoLocalizations` 的用例补 `cupertino_ui` 的 `DefaultCupertinoLocalizations.delegate` 或改 `CupertinoApp` 宿主。
- 10 个用 `find.byType(Scaffold/AppBar/ListTile/...)` 的测试改成语义 / key 断言。
- 根 `scripts/check_ui_boundary.dart` 必须零失败。

## 7. 交付拆分

| PR | Issue | 内容 |
|----|-------|------|
| 1 | `#128` | 工具链 3.47.5、依赖、根、主题、岛、壳层、边界脚本 |
| 2 | `#129` | 任务页 |
| 3 | `#130` | 日历（含 golden 重录） |
| 4 | `#131` | 记录 |

每个 PR 独立分支、独立验证、PR 指向 `develop`。

## 8. 风险与回滚

| 风险 | 规避 |
|------|------|
| Flutter 3.47.5 升级带来的既有包回归 | #128 内先跑四个包 analyze + 全量 test；红灯先记录基线再动手 |
| 根切 Cupertino 后未迁移页面丢 Material 主题（默认紫） | `#128` 用 `LifeMaterialIsland` 临时包住未迁移的三个 App，随各自 PR 移除 |
| 缺 `ScaffoldMessenger` / `GlobalMaterialLocalizations` 导致运行时断言 | 根 builder 提供 `ScaffoldMessenger`；delegates 常驻 |
| 残留 `MaterialPageRoute` / `showModalBottomSheet` 与 Cupertino 返回手势冲突 | 每个 App 的 PR 内清零，边界脚本拦 `MaterialPageRoute` |
| 测试宿主缺 `cupertino_ui` 本地化 | 按失败清单补 delegate 或换宿主 |
| golden 重录掩盖真实回归 | 重录前后人工比对，golden 变更单独提交 |

回滚：每个 PR 可独立 revert；`#128` revert 即回到 Material 根，后续 PR 依赖它。

## 9. 已知限制

- `kalender` 与 `flutter_quill` 内部仍是 Material 外观；本轮只保证外壳与配色一致。
- 不做暗色主题（现状全仓只处理亮色）。
- 不补功能缺口。
