# zh-cloud-lifeos-flutter

LifeOS **生活台**私有 Flutter 仓（Melos + Dart pub workspace）。

产品隐喻：个人域的飞书式「工作台 + 开放应用」；第一方应用自现 `todo-flutter` 拆出（任务 / 日历 / 习惯…）。任务 UX 金标准为 Apple「提醒事项」三端复刻。

## 结构

```text
apps/
  life_launcher/          # 生活台壳（Tab + 更多）
packages/
  app_core/               # 会话 / dio / 设计令牌
  life_link/              # 跨应用深链契约
  feature_productivity_kernel/  # 提醒实体与本地端口
  feature_task/           # 提醒事项 UI（开源侧）
```

## 环境

- Flutter **3.44.x** / Dart **3.12.2**（本机当前 SDK）
- 依赖取 pub.dev **最新可解析正式版**；受 SDK 钉死版本限制的包见下方「钉版说明」

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd zh-cloud-lifeos-flutter
dart pub get
cd apps/life_launcher && flutter run -d macos   # 或 chrome / 真机
```

全仓分析 / 测试（需已 `dart pub global activate melos`，或用 `dart run melos`）：

```bash
dart run melos analyze
dart run melos test
```

## 钉版说明（相对 pub 绝对最新）

| 包 | 本仓 | 原因 |
|----|------|------|
| `google_fonts` | ^8.2.1 | 9.x 需 Dart ^3.13 |
| `table_calendar` | ^3.2.1 | 3.3 需 intl≥0.20.3；Flutter 钉 intl 0.20.2 |
| `cached_network_image` | ^3.4.1 | 4.x→material_ui 需 Dart 3.13 |
| `sqlite3` | ≥3.4 <3.6 | 3.7→hooks→meta^1.19；Flutter 钉 meta 1.18 |
| `hooks`（override） | 2.0.0 | 同上 |
| `freezed` / `riverpod_generator` | 暂未引入 | freezed 4 需 Dart ≥3.13，与 generator 注解链冲突 |

**升级 Flutter 到 Dart ≥3.13 后**可去掉 `dependency_overrides`，并加回 freezed 4 + riverpod_generator 4 + google_fonts 9 等。

## Git

- 集成线 `develop`，发布线 `main`；禁止直推主干，合并走 PR
- commit：`<type>(<scope>): <中文描述>`

## 文档

- 跨仓设计：`zh-cloud/.cursor/plans/life-client/2026-10-22-c-end-life-flutter-modular-design.md`
- 本仓总览：`spec.md`
