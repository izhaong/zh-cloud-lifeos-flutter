# zh-cloud-lifeos-flutter

LifeOS 个人生活开放平台 Flutter 客户端（私有 Melos 仓）。

## 定位

- 生活台壳 `life_launcher`：飞书式底部 Tab（≤5）+ 最右「更多」+ App Store 入口
- 第一方：`feature_task`（提醒事项三端复刻）→ 后续 calendar / habit / CDSM
- 契约：`life_link`；共享实体/端口：`feature_productivity_kernel`；持久化：`feature_productivity_drift`；私有壳能力：`app_core`
- 拍板：**F1**（开源 Noop sync）+ **G3**（多独立 App）+ **H1**（自营目录）

跨仓设计权威：`zh-cloud/.cursor/plans/life-client/2026-10-22-c-end-life-flutter-modular-design.md`。

## 技术栈（基建期）

| 层 | 选型 |
|----|------|
| 状态 | Riverpod 3 / hooks_riverpod |
| 路由 | go_router 18（全仓唯一 GoRouter；任务全屏走 shell 外顶层路由） |
| 网络 | dio 5 |
| 本地库 | Drift 2.35（feature_productivity_drift 实现端口；codegen 已实测 Dart 3.12.2 可用） |
| 会话 | flutter_secure_storage 11 |
| UI | Material 3、flutter_svg、google_fonts、material_symbols_icons、flutter_animate |
| 通知/日历 | flutter_local_notifications、table_calendar、timezone |
| i18n | slang（基建期已入依赖，文案后续） |
| 断点 | WindowSizeClass 三档纯函数（kernel）：<600 栈 / 600–1199 二栏 / ≥1200 三栏 |

功能级规格落 `specs/<NNN>/`（spec-kit）；本文件仅仓库总览。

## 非目标（首期）

- 不把旧 `todo-flutter` 整包嵌入
- 不上线开放目录 / 第三方 OAuth（Phase 5）
- 代码生成链（freezed 4 / riverpod_generator）待 Dart ≥3.13
