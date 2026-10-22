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
- Drift / freezed / riverpod_generator：升级 Dart ≥3.13 后再系统性启用 codegen

## Architecture

```text
life_launcher → feature_*_cloud（后续）/ feature_task + app_core
feature_task  → feature_productivity_kernel
app_core      → life_link
跨 App        → LifeLink 深链（禁止 feature 互 import UI）
```

- `AuthPort` / `SyncPort`：接口 + Noop；真实实现只在 `*_cloud`
- 任务 UX：Apple 提醒事项 iPhone / iPad / macOS 对等（见父仓 reminders 线框）

## Project Structure

见 `README.md` 结构树；`docs/contracts/` 放 LifeLink 等对外契约。

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
- Subagent：优先 `flutter-dev` / 后续 `lifeos-flutter-dev`
- 安全：不输出真实 token / 密钥
