# zh-cloud-lifeos-flutter

LifeOS **生活台**私有 Flutter 仓（Melos + Dart pub workspace）。

产品隐喻：个人域的飞书式「工作台 + 开放应用」；第一方应用自现 `todo-flutter` 拆出（任务 / 日历 / 习惯…）。任务 UX 金标准为 Apple「提醒事项」三端复刻。

## 结构

```text
apps/
  life_launcher/          # 生活台壳（Tab + 更多；GoRouter 唯一装配在 lib/router/）
packages/
  app_core/               # 会话 / dio / 设计令牌
  life_link/              # 跨应用深链契约
  feature_productivity_kernel/  # 提醒实体、仓库端口、WindowSizeClass 断点纯函数
  feature_productivity_drift/   # ReminderRepository 的 Drift 持久化实现
  feature_task/           # 提醒事项 UI（开源侧）
```

## 环境

- Flutter **3.44.x** / Dart **3.12.2**（本机当前 SDK）
- 依赖取 pub.dev **最新可解析正式版**；受 SDK 钉死版本限制的包见下方「钉版说明」

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd zh-cloud-lifeos-flutter
# 直连 pub.dev 若卡在大包（material_symbols_icons / riverpod / drift），可临时：
# export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
dart pub get
cd apps/life_launcher && flutter run -d macos   # 或 chrome / 真机
```

全仓分析 / 测试（melos 8 脚本定义在根 `pubspec.yaml` 的 `melos:` 段）：

```bash
dart run melos run analyze
dart run melos run test
dart run melos run gen    # build_runner（feature_productivity_drift 的 drift 表生成）
```

> 注意：melos 8.9 不再读取 `melos.yaml` 的 scripts，且 `melos analyze`/`bootstrap` 是内置命令；自定义脚本必须走 `melos run <名字>`。

## 钉版说明（相对 pub 绝对最新）

| 包 | 本仓 | 原因 |
|----|------|------|
| `google_fonts` | ^8.2.1 | 9.x 需 Dart ^3.13 |
| `table_calendar` | ^3.2.1 | 3.3 需 intl≥0.20.3；Flutter 钉 intl 0.20.2 |
| `cached_network_image` | ^3.4.1 | 4.x→material_ui 需 Dart 3.13 |
| `sqlite3` | ≥3.4 <3.6 | 3.7→hooks→meta^1.19；Flutter 钉 meta 1.18 |
| `hooks`（override） | 2.0.0 | 同上 |
| `drift_dev` | ^2.35.1 | 2.35.2 约束在 Dart 3.12.2 不可解析（实测降 2.35.1 通过） |
| `freezed` / `riverpod_generator` | 暂未引入 | freezed 4 需 Dart ≥3.13，与 generator 注解链冲突 |

**升级 Flutter 到 Dart ≥3.13 后**可去掉 `dependency_overrides`，并加回 freezed 4 + riverpod_generator 4 + google_fonts 9 等。

## 平台矩阵与多端降级

| 平台 | 布局 | 说明 |
|------|------|------|
| iPhone（<600dp） | 列表首页 → 栈导航 → 全屏详情模态 | 嵌生活台时任务页走 shell 外顶层路由，无双底栏 |
| iPad 竖屏 / 11" 横屏（600–1199dp） | 分栏二栏（侧栏 \| 列表） | 与系统 Reminders 一致 |
| iPad 12.9"/13" 横屏、macOS（≥1200dp） | 三栏（侧栏 \| 列表 \| 详细信息） | ⌘N 新建提醒、⌘F 聚焦搜索 |
| Android 手机 / Web 窄窗 | 走 iPhone 式栈导航 | 纯宽度判定，无需平台分支 |
| Android 平板 / Web 宽窗 | 优先 iPad 分栏 | 无桌面菜单栏时用应用内工具栏代替 macOS 菜单 |

降级不改变数据模型与智能列表语义：断点只换外壳布局（`WindowSizeClass`），业务逻辑零分叉。

## 布局断点（任务 App · 已钉死）

`WindowSizeClass.fromWidth`（`feature_productivity_kernel`，纯函数，单一取值点）：

| 档 | 宽度（dp） | 布局 |
|----|-----------|------|
| compact | <600 | iPhone 栈导航单栏；全屏详情走 shell 外顶层路由（无双底栏） |
| medium | 600–1199 | iPad 分栏二栏（侧栏 \| 列表） |
| expanded | ≥1200 | 可开第三列「详细信息」（iPad 12.9"/13" 横屏、macOS 默认窗） |

纯宽度判定，无平台分支；断点只换外壳，不产生业务逻辑分叉。

## 数据装配（Riverpod 契约）

- `reminderRepositoryProvider` 在 `feature_task` 定义（未注入即抛 UnimplementedError）
- 组合根 `apps/life_launcher/lib/main.dart` 先开 Drift 库再 `overrideWithValue` 注入
- 测试内 override `InMemoryReminderRepository` 即可独立跑 feature_task 全套 widget 测试
- `melos gen` 跑 build_runner（当前仅 `feature_productivity_drift` 需要）

## Git

- 集成线 `develop`，发布线 `main`；禁止直推主干，合并走 PR
- commit：`<type>(<scope>): <中文描述>`

## 文档

- 跨仓设计：`zh-cloud/.cursor/plans/life-client/2026-10-22-c-end-life-flutter-modular-design.md`
- LifeLink 契约（权威）：`docs/contracts/life-link.md`（能力 ID + OAuth scope 命名空间）
- CI 预留计划：`docs/ci-plan.md`
- 本仓总览：`spec.md`
