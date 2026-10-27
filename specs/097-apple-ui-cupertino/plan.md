# Plan · Apple 平面风 UI 统一

依据：[spec.md](./spec.md)。每个 PR 独立分支、独立门禁。

## PR 1 · 底座 + 壳层（#128）

分支：`feat/128-ui-cupertino-wt`（并行会话占用原工作树，UI 工作在独立 worktree）

0. 工具链基线（已由 `09a89dd` 提交）
   - Flutter 3.47.5 / Dart 3.13.4；移除根 `intl` / `hooks` 钉版。
   - 五个 `analysis_options.yaml` 排除 `build/**`、`android/**`、`ios/**`、`web/**`、`windows/**`、`macos/**`、`linux/**`。
   - 验证：`flutter --version`；`flutter pub get`；四包 `flutter analyze --fatal-infos` 绿。

1. 依赖
   - `apps/life_launcher/pubspec.yaml`、`packages/app_core/pubspec.yaml`、`packages/feature_task/pubspec.yaml`、`packages/feature_calendar/pubspec.yaml`、`packages/feature_note/pubspec.yaml` 加 `cupertino_ui: ^1.1.4`。
   - 删除 `feature_task` 的 `google_fonts`、`material_symbols_icons`、`flutter_svg`、`flutter_animate`（lib/test 零引用）。
   - `flutter pub get`，确认 `cupertino_ui 1.1.4` 锁定。
   - 验证：`git diff pubspec.lock` 只出现 dependency 类型变化，不出现版本跳动。

2. 主题与岛
   - `packages/app_core/lib/src/theme/life_tokens.dart`：新增 `cupertino()`；`light()` 改名 `materialIsland()`。
   - 新增 `packages/app_core/lib/src/theme/life_material_island.dart`，并在 `app_core.dart` 导出。
   - 验证：`cd packages/app_core && flutter analyze --fatal-infos && flutter test`。

3. 根
   - `apps/life_launcher/lib/main.dart`：`CupertinoApp.router`；delegates 补 `GlobalCupertinoLocalizations`（`cupertino_ui`）与 `GlobalMaterialLocalizations`（SDK）；`builder` 提供 `ScaffoldMessenger`。
   - 验证：`grep -n "CupertinoApp.router" apps/life_launcher/lib/main.dart`；macOS 启动无 `No CupertinoLocalizations found` 断言。

4. 过渡岛
   - `apps/life_launcher/lib/router/life_router.dart`：用 `LifeMaterialIsland` 包住 `TaskTabEntry`、`CalendarTabEntry`、`NoteTabEntry`，避免未迁移页面丢主题。
   - 验证：三页可打开，无默认紫。

5. 壳层
   - `app_registry.dart`：Material `Icons.*` 换 `CupertinoIcons.*`。
   - `life_shell.dart`：compact 换 `CupertinoTabBar`；宽屏换自定义侧栏（`CupertinoListTile` + 0.5px 分隔线）；徽标换本地 `_Badge`。
   - `more_page.dart`：`CupertinoPageScaffold` + `CupertinoNavigationBar` + `CupertinoListSection`；`SnackBar` 换 `showCupertinoDialog`。
   - `placeholder_page.dart`：`CupertinoPageScaffold` + `CupertinoNavigationBar`。
   - 验证：`cd apps/life_launcher && flutter analyze --fatal-infos && flutter test`。

6. 边界门禁
   - 新增 `scripts/check_ui_boundary.dart`：扫描四包 `lib`，白名单外出现 `package:flutter/material.dart` 即失败；同时禁止白名单外出现 `MaterialPageRoute` / `ScaffoldMessenger`。
   - 根 `pubspec.yaml` 加 melos 脚本 `ui-boundary`。
   - 验证：`dart run scripts/check_ui_boundary.dart` 零失败；临时在壳层文件插一行 Material import 时脚本必须红。

7. 实机验证
   - `flutter run -d macos`，截 1280 / 1024 / 375 三档；检查 Tab 选中态、侧栏分隔线、徽标、更多页编辑态。
   - 手动点：任务 / 日历 / 记录 / 更多 / 占位页均可打开；返回手势正常。

8. 收口
   - `git diff --check`；四包 `flutter analyze --fatal-infos` 全绿（含未迁移包，确认工具链基线没把它们弄红）。
   - `dart run melos run test` 若时间允许则跑全仓；至少跑 `life_launcher` 与 `app_core` 全量测试。
   - 提交：`feat(ui): 壳层与根切换 cupertino_ui（#128）`。
   - 推送并开 PR，正文 `Fixes #128`、`Refs #127`。

## PR 2 · 任务（#129）

分支：`feat/129-task-cupertino`

1. 逐文件替换 Material 组件（清单见 spec §5.2），保留 `ReminderTokens`。
2. `life_router.dart` 移除 `TaskTabEntry` 的过渡岛。
3. 更新受影响测试：`find.byType(Scaffold/AppBar/ListTile/IconButton/TextField/AlertDialog/SnackBar)` → 语义 / key。
4. 门禁：`feature_task` + `life_launcher` analyze/test；边界脚本白名单收紧。
5. macOS 截图：侧栏 / 列表 / 详情 inspector / 设置弹层。

## PR 3 · 日历（#130）

分支：`feat/130-calendar-cupertino`

1. 外壳换 Cupertino（清单见 spec §5.3）。
2. `kalender` / `table_calendar` 进 `LifeMaterialIsland`；`cupertino_calendar_picker` 局部 `CupertinoTheme`。
3. `life_router.dart` 移除 `CalendarTabEntry` 的过渡岛。
4. 更新测试；golden 重录前单独取得用户授权，重录后人工比对三张图。
5. 门禁：`feature_calendar` + `life_launcher` analyze/test；边界脚本收紧。

## PR 4 · 记录（#131）

分支：`feat/131-note-cupertino`

1. 外壳换 Cupertino（清单见 spec §5.4）。
2. `flutter_quill` 进 `LifeMaterialIsland`。
3. `life_router.dart` 移除 `NoteTabEntry` 的过渡岛；`main.dart` 移除根 `ScaffoldMessenger`。
4. 更新测试；门禁：`feature_note` + `life_launcher` analyze/test。
5. 边界脚本最终白名单：两个内核文件 + `life_tokens.dart`。

## 回滚

任一 PR 可独立 revert。`#128` revert 后回到 Material 根；`#129`–`#131` 依赖 `#128`，按逆序 revert。
