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
flutter test   # 在各 package / app 目录，或 melos test
```

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
- 导航：全仓**唯一** `GoRouter`（`apps/life_launcher/lib/router/life_router.dart`）；任务全屏页走 shell 外顶层路由（无双底栏）
- 断点：`WindowSizeClass.fromWidth`（kernel 纯函数）三档——compact <600dp 栈导航 / medium 600–1199 二栏 / expanded ≥1200 可开第三列；叶子内容 widget 禁读断点
- 任务 UX：Apple 提醒事项 iPhone / iPad / macOS 对等（见父仓 reminders 线框）

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
- 规则：父仓 `00-zh-cloud-core`；本仓 `.cursor/rules`（bootstrap 后）
- **长目标与交叉验证**：父仓 `.cursor/plans/life-client/2026-10-22-lifeos-long-goal-prompt.md`。重大架构/导航/数据层方案须经 **`cursor-agent` × `claude` CLI** 只读交叉评审，合出推荐后**直接按推荐落地**，不要等人做 A/B；额度失败则本地降级评审（见该文 §H / F.10）
- Subagent：优先 `flutter-dev` / 后续 `lifeos-flutter-dev`
- 安全：不输出真实 token / 密钥
