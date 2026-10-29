# Agent 入口（zh-cloud-lifeos-flutter）

> 本文件与 `CLAUDE.md` 同源。修改约定时两份一起更新。

LifeOS **生活台** Flutter Melos 仓：壳 `apps/life_launcher` + `packages/*`。后端账号仍在 `zh-cloud-service`；跨仓设计见父仓 `.cursor/plans/life-client/`。

## Coding Principles

全局 `karpathy-guidelines`：Think Before Coding → Simplicity First → Surgical Changes → Goal-Driven Execution。

## Spec

仓库总览 [spec.md](./spec.md)。功能级规格以 `specs/<NNN>/{spec,plan,tasks}.md` 为唯一事实源（spec-kit）。

## Development

根目录为 Dart **pub workspace**（`pubspec.yaml` 的 `workspace:`）+ Melos。

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
dart pub get
cd apps/life_launcher && flutter run -d macos
dart analyze
flutter test   # 在各 package / app 目录，或 dart run melos run test
dart run melos run verify   # 合前门禁：analyze(--fatal-infos) + UI 边界(先自检) + 全包测试
dart run scripts/golden_sheet.dart   # 目视走查：把 16 张 golden 拼成一页（build/golden-sheet/index.html）
dart run scripts/check_skipped_tests.dart   # 守卫：测试不得被静默 skip（已在 melos run verify 里）
dart run scripts/check_awaited_writes.dart   # 守卫：测试里的异步写必须 await（#433，已在 verify 里）
dart run scripts/check_native_assets.dart    # 出包前预检（联网）：sqlite3 原生资产直链（#389，不在 verify 里）
# 若 verify 在并行下偶发抖动（已知：feature_productivity_drift 的关库重开测试，#361），
# 用串行兜底再跑一遍测试阶段确认：
#   dart run melos exec --concurrency=1 --dir-exists=test -- flutter test
```

### CI 现状（#322，2026-10-28 核实）

本仓 `.github/workflows/ci.yml` 会创建 run，但 **Gitea 实例零 runner**
（`GET /admin/actions/runners` → `{"runners":[],"total_count":0}`）：completed 的 run
**全部是 cancelled**，从未出现 success。所以：

- **不要**假设 CI 会替你发现红；
- 合前一律跑 `dart run melos run verify`，并把输出贴进 PR（模板已要求）；
- runner 就绪前，`--fatal-infos` 与 UI 尺子只由本地这条命令保证。

- Dart SDK 随本机 Flutter（当前 3.12.2）；依赖钉版说明见 `README.md`
- Drift codegen（drift_dev 2.35.1 + build_runner）已在 Dart 3.12.2 实测可用：`packages/feature_productivity_drift` 内 `dart run build_runner build`
- freezed 4 / riverpod_generator 4：仍待 Dart ≥3.13 后启用

## Architecture

```text
life_launcher → feature_*_cloud（后续）/ feature_task + app_core
life_launcher → feature_productivity_drift（组合根注入仓库实现）
feature_task  → feature_productivity_kernel（契约 Provider 在 feature_task 定义，组合根 override）
app_core      → life_link
跨 App        → LifeLink 深链（禁止 feature 互 import UI）
```

- `AuthPort` / `SyncPort`：接口 + Noop；真实实现只在 `*_cloud`
- 数据仓库：`ReminderRepository` 端口在 kernel；`InMemory`（kernel 内参考实现）与 `Drift`（`feature_productivity_drift`）双实现，组合根单点切换
- 导航：全仓**唯一** `GoRouter`（`apps/life_launcher/lib/router/life_router.dart`）；任务列表子路由嵌在 StatefulShell 内（`/` + `/list/:id`），**壳应用栏常显**（compact 竖屏底 Tab；横屏或 medium/expanded 左轨）
- 断点：`WindowSizeClass.fromWidth`（kernel 纯函数）三档——compact <600dp 栈导航 / medium 600–1199 二栏 / expanded ≥1200 可开第三列；叶子内容 widget 禁读断点
- 任务 UX：Apple 提醒事项 iPhone / iPad / macOS 对等（见父仓 reminders 线框）

### UI / 多端视觉约束（强制）

目标端：**Android · iOS · macOS · Windows · Web**。`cupertino_ui` / SDK Material 均可在五端渲染；选型影响观感，不是「某端跑不起来」。权威规格：`specs/097-apple-ui-cupertino/`；边界脚本：`dart run scripts/check_ui_boundary.dart`（收口后加 `--strict`）。

1. **宿主**：全仓唯一根为 **`CupertinoApp.router`（`package:cupertino_ui/cupertino_ui.dart`）**，`theme: LifeTokens.cupertino()`；delegates 含 `GlobalCupertinoLocalizations`（cupertino_ui）+ `GlobalWidgetsLocalizations` + `GlobalMaterialLocalizations`（供 Material 岛）。根 `builder` 挂 `Theme(data: LifeTokens.materialIsland())` + `ScaffoldMessenger`（过渡期）。**禁止**改回 `MaterialApp` 作业务根；**禁止**用 SDK `package:flutter/cupertino.dart` 的 `CupertinoApp` 作根（`go_router` 的 `isCupertinoApp()` 只认 `cupertino_ui`，否则丢转场）。
2. **统一视觉语言**：五端共用 **LifeOS / Apple 平面风**，**不要**按 `Platform.is*` / `defaultTargetPlatform` 维护第二套页面树或「跟系统走」的双皮肤。Android / Windows / Web 允许偏 iOS 移植感。
3. **布局只跟宽度**：分栏 / 底栏 / 左轨 **只**经 `WindowSizeClass.fromWidth`；断点只换外壳，不改业务逻辑。叶子内容 widget **禁读**断点与平台。**禁止**用 `Platform.is*` / `kIsWeb` 决定 1/2/3 栏或整页结构。
4. **组件来源（自有 UI）**：只准 **`cupertino_ui`**（及已钉的点状包如 `cupertino_calendar_picker`）。**禁止**自有 UI `import package:flutter/material.dart` / `package:flutter/cupertino.dart`（SDK Cupertino 易与 `cupertino_ui` 类型分叉）。**禁止**再引入整包第三方 UI Kit（Fluent / Forui / shadcn / 实验性 Liquid Glass 等）充当第二底座；**禁止**再叠第二套日历 UI 与 `kalender` / `table_calendar` / cupertino picker 打架。
5. **Material 仅限显式岛**：`kalender` / `flutter_quill` 等第三方内核包在 `LifeMaterialIsland`（`app_core`）内；主题用 `LifeTokens.materialIsland()`（勿 `ColorScheme.fromSeed`，避免与 brand 色分叉）。业务路由用 Cupertino 页转场；**禁止**新增 `MaterialPageRoute` / 裸 `showModalBottomSheet`（迁移清单见 `check_ui_boundary.dart` 白名单，应收口删除）。
6. **设计令牌**：跨 App 令牌在 `app_core` 的 `LifeTokens`（`cupertino()` / `materialIsland()`）。`feature_*` **互不 import UI**；只消费 `app_core` / 共享 tokens。
7. **平台差异只留能力层**：Web DB、本地通知、SecureStorage、桌面标题栏/托盘等可 `kIsWeb` / 平台分支；**不得**渗进 `feature_task` / `feature_calendar` / `feature_note` 的业务 UI 树。桌面中长期加窗口 chrome，不换 `cupertino_ui` 底座；布局仍用 expanded 三栏。
8. **素材**：不引入 SF 字体文件与 Apple 专有资源；图标用 Cupertino Icons / Material Symbols（岛内）/ 自研近似（见各 App 对等矩阵与 specs）。

## Project Structure

见 `README.md` 结构树；`docs/contracts/life-link.md` 为 LifeLink **权威契约**（能力 ID / OAuth scope 命名空间已冻）；`docs/ci-plan.md` 为 CI 预留计划。

## Tech Stack

Flutter · Riverpod 3 · go_router · Drift · dio · equatable · slang · Melos。

## Git Workflow

- 集成线 `develop`，发布线 `main`；禁止直推主干，PR 合并
- 分支带 Issue：`feat/<n>-…`；PR 描述 `Fixes #n` / 跨仓 `Refs #n`
- commit：`<type>(<scope>): <中文描述>`
- **Agent 默认不 commit / push，除非用户明确要求**

## Testing Safety

测试不连真实后端、不发真实网络；Drift 用内存/临时库；密钥不入库。

## Key Conventions

- 登录可跳过；离线优先
- **UI / 多端**：见上文「UI / 多端视觉约束（强制）」——`cupertino_ui` 的 `CupertinoApp` 宿主、Material 仅显式岛、五端统一 LifeOS 皮肤、布局只认 `WindowSizeClass`、禁止第二套 UI Kit / 按平台分叉页面树；边界用 `scripts/check_ui_boundary.dart`
- 规则：父仓 `00-zh-cloud-core`；本仓 `.cursor/rules`（bootstrap 后）
- **长目标与交叉验证**：父仓 `.cursor/plans/life-client/2026-10-22-lifeos-long-goal-prompt.md`。重大架构/导航/数据层方案须经 **`cursor-agent` × `claude` CLI** 只读交叉评审，合出推荐后**直接按推荐落地**，不要等人做 A/B；额度失败则本地降级评审（见该文 §H / F.10）
- Subagent：优先 `flutter-dev` / 后续 `lifeos-flutter-dev`
- 安全：不输出真实 token / 密钥
