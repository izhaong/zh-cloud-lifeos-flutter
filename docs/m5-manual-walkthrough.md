# M5 多端回归 · 手动走查清单（TC-REG-101/103/104/106/109/110/111）

> 执行环境：macOS 桌面（flutter run -d macos）+ Chrome（flutter run -d chrome）为必跑；
> Android/iPad 真机如具备则加跑，不具备则记录「设备不可用」并在回归报告注明。
> 每项走完在 [ ] 打 x，异常截图归档 `zh-cloud-docs/lifeos/04_测试与质量/m5-regression/`。

## TC-REG-101 平台矩阵 × 核心链路（P0）

每平台按序执行，任何一步崩溃/白屏即 FAIL：

- [ ] **macOS**：新建列表 → 新建提醒 → 详情编辑（备注/优先级/旗标）→ 完成（圆圈划线）→ 搜索命中 → 删除（回收窗可见）
- [ ] **Web(chrome 宽屏)**：同上链路（三栏：侧栏|列表|inspector）
  —— 启动白屏阻塞已于 2026-10-26 解除（Issue #84，Web 接入 drift WASM），
  三栏渲染 + 新建 + 刷新不丢已实测；本行**整条链路**（详情编辑/完成/搜索/删除回收窗）仍未走完，故不打勾。
- [ ] **Web(chrome 窄窗 <600)**：同上链路（栈导航降级）
- [ ] **Android 手机**（如有）：同上链路
- [ ] **iPad 横竖屏**（如有）：横=双栏、竖=底 Tab；同上链路

## TC-REG-103 桌面快捷键（P1；flutter_test 无法模拟修饰键）

- [ ] **macOS**：⌘N → 出现草稿行并聚焦；⌘F → 焦点进工具栏搜索框
- [ ] **Windows**（如有）：Ctrl+N / Ctrl+F 同效
- [ ] **无死键**：在详情面板/设置弹层打开时按上述键不卡死

## TC-REG-104 i18n 抽查（P1）

- [ ] 系统切英文：任务首页/详情/设置弹层无硬编码中文残留（设置弹层首期占位文案允许中文，记 P1 债）
- [ ] 日期显示随 locale 本地化（Today/今天）

## TC-REG-106 golden 关键屏（P1）

对拍 `zh-cloud-docs/lifeos/wireframes/` 金标准截图（人工对照）：

- [ ] 手机首页（智能卡 2×2 + 我的列表）vs `reminders-iphone-lists.png`
- [ ] Pad 双栏 vs `ref-ipad-reminders-sidebar.jpg`
- [ ] 客户端三栏 vs `ref-macos-reminders-main-sidebar.png`
- [ ] 隐藏侧栏铺满 vs `ref-macos-reminders-sidebar-hidden.png`
- [ ] 新建列表模态 vs `ref-macos-reminders-new-list.png`

## TC-REG-109 Web 特有（P1）

> 前置：深链依赖服务端 SPA 回退（未知路径 → `index.html`）。用 `python3 -m http.server`
> 这类静态服务器直链会 404，那是**测试脚手架**的限制，不能据此判产品缺陷。

- [x] 宽屏直接刷新 `/` → 恢复任务首页（2026-10-26 实测）
- [x] 深链 `/list/smart.today` → 直接进「今天」视图（2026-10-26 实测，侧栏「今天」高亮）
- [ ] 窄窗深链同上 → 栈导航形态正确
- [x] 刷新后数据在（本地库不丢）（2026-10-26 实测：新建「web持久化验证」→ reload → 条目与
      智能列表计数（今天 1 / 全部 1 / 紧急 1）均在；drift 选中 `sharedIndexedDb` 后端）

## TC-REG-110 无障碍基线（P2 抽查）

- [ ] 完成圆圈有语义标签（读屏读出「完成 买牛奶」类）
- [ ] 底栏 Tab / 侧栏列表行可聚焦键盘导航

## TC-REG-111 服务端冒烟（P0，脚本）

```bash
# staging（Jenkins 晋升后容器内跑）
# IDEA HTTP Client 顺序执行：
# yudao-module-todo/.../AppTodoLifeosM1Smoke.http（12 步；M1 收口时 9/12 绿口径）
# lifeos-task 装配冒烟：
curl http://<host>:48080/app-api/lifeos/task/ping   # → {"module":"yudao-module-lifeos-task",...}
```

- [ ] M1 冒烟 12 步通过（或记录既有 3 缺口=lifeos-task 复制清单项）
- [ ] lifeos-task ping 200

## TC-REG-112 依赖与体积（P0，已自动化于本 PR）

- [x] `grep package:drift|sqlite3|app_core packages/feature_task/lib` 零命中
- [x] kernel 无 drift；feature_* 互不 import UI；feature_task 无 dio/secure_storage
- [x] CI grep 门禁脚本建议随 Jenkins/Gitea Actions 落地（docs/ci-plan.md 已列）

---

## 结论回填

| 用例 | 结果 | 证据 |
|------|------|------|
| TC-REG-102 三档回归 | ✅ 已自动化（tc_reg_regression_test.dart 四宽度断点） | 本 PR |
| TC-REG-107 负向门禁全量 | ✅ 已自动化（同上双档无泄漏断言） | 本 PR |
| TC-REG-108 生命周期 | ✅ 已自动化（重建重订阅+回前台写驱动） | 本 PR |
| TC-REG-105 千级性能 | ✅ 已自动化（1000 条 <10s + 搜索在线；真机 jank 属手动） | 本 PR |
| TC-REG-112 边界 grep | ✅ 已执行（四组 grep 全零命中） | 本 PR |
| TC-REG-101/103/104/106/110/111 | 手动（本清单） | 待设备走查归档 |
| TC-REG-109 Web 特有 | 部分手动（4 项中 3 项已实测） | 2026-10-26 Web 复验记录 |

---

## 实机复验记录（2026-10-24，macOS）

### 批 1–2 修复项（PR 分支 fix/m5-parity-gaps，cursor 图评两轮）

| 项 | 状态 | 证据 |
|----|------|------|
| P0-1 侧栏顶小图标（新建\|隐藏\|设置） | ✅ cursor r3 图评确认 | 无底栏三等分钮 |
| P2 搜索细边白底/侧栏浅灰/空态引导 | ✅ cursor r3 图评确认 | 图评原文「已修复」 |
| P0-2 顶栏＋ | ✅ cursor r3 图评确认 | `toolbar_new_item` 可见 |
| P0-2 空列表大标题 | ✅ 第 3 批重构+回归测试 | `tc_reg_regression_test.dart` descendant 断言 |
| P0-5 空列表+⌘N 草稿行 | ✅ `_showDraft` 守卫+回归测试 | 同上（工具栏＋点击路径全绿） |
| P0-3 0 完成无「清除」 | ✅ 代码 doneCount>0 才渲染 | `_ListHeaderToolbar` |
| P1-2 ⋯ 菜单 | ✅ PopupMenuButton | `list_more_menu` |

### 截图归档
- `docs/m5-regression-evidence/macos-main-after-parity-batch3.png`（第三批后主界面，精确窗口区域截屏）

### 待续（cursor 额度 11/18 重置后补跑）
- ⌘N 系统级快捷键实机走查（辅助访问权限需用户授予 osascript；自动化侧 19 项测试已覆盖行为）
- P2 质感收敛：底栏＋样式、侧栏角标全量、分享钮、设置图1 真身（列于下一批清单）

---

## 实机复验记录（2026-10-26，Web / Chrome）

Issue #84：Web 端此前**启动即纯白屏**，TC-REG-101 与 109 整条无法执行。

### 根因

`apps/life_launcher/lib/main.dart` 在 `runApp` 之前无条件 `await openDefaultDatabase()`，
而该方法对 `kIsWeb` 直接 `throw StateError`。`main()` 中断 → 白屏（不是红屏，因为框架还没起来）。
全仓 `flutter test` 当时**全绿**，这条缺陷在自动化侧完全量不到。

### 修复

Web 分支改走 drift 的 WASM 后端。`drift_flutter 0.3.1` 的 `lib/src/connect.dart`
用条件导出内置了 web 实现，因此不需要手写连接工厂，只需传 `DriftWebOptions`。
新增两份 `apps/life_launcher/web/` 静态资源，来源与 `pubspec.lock` 钉版严格对齐：

| 资源 | 来源 | 体积 |
|------|------|------|
| `sqlite3.wasm` | `simolus3/sqlite3.dart` release tag `sqlite3-3.5.2` | 748,686 B |
| `drift_worker.js` | pub 包 `drift-2.35.2` 根目录预构建产物 | 360,104 B |

原生开库路径**字节未变**：macOS 沙盒里的实际文件名是
`~/Library/Containers/com.zhcloud.lifeos.lifeLauncher/Data/Documents/life_productivity.sqlite.sqlite`
（双 `.sqlite` 后缀，因为把绝对路径当 `name` 传给了 `driftDatabase`，后者又拼了一次目录与后缀）。
本批故意不改——改 `name` 会让原生端去开一个新文件、把既有数据孤儿化。双后缀另立存量问题。

### 实测结论（`flutter build web` + 本地 SPA 回退服务 + Chrome）

| 项 | 结果 | 证据 |
|----|------|------|
| 启动不再白屏 | ✅ | 页面标题由 `life_launcher` 变为 `LifeOS 生活台`，三栏任务界面渲染 |
| drift 选中持久化后端 | ✅ | 控制台 `Using WasmStorageImplementation.sharedIndexedDb due to missing browser features: {...}` |
| 库真的建出来了 | ✅ | `indexedDB.databases()` 返回 `["life_productivity\|1"]` |
| 新建提醒 | ✅ | 底栏「新提醒事项」→ 草稿行输入 → 回车 → 行出现，侧栏计数 今天 1 / 计划 1 / 全部 1 / 紧急 1 |
| 刷新不丢（TC-REG-109） | ✅ | reload 后条目「web持久化验证」与上述计数仍在 |
| 深链（TC-REG-109） | ✅ | `/list/smart.today` 直达「今天」视图 |

### 脚手架坑（复跑必读）

- 深链要服务端 SPA 回退。`python3 -m http.server` 对 `/list/smart.today` 返回 404，
  是脚手架缺回退，不是产品缺陷。
- 回退判据不能写成「路径里没有 `.` 才回退」——路由名 `smart.today` 自带点，会被误判成静态文件。
  要按扩展名白名单判。
- Flutter Web 语义树默认不构建，`take_snapshot` 只拿到空壳；先点 `FLT-SEMANTICS-PLACEHOLDER`
  （无障碍占位符）才有可交互 uid。每次导航后 uid 重编。
- IndexedDB 按 origin 隔离，**换端口等于换库**。8931 建的数据在 8933 上必然看不到，别当成丢数据。

### 仍未做（另立）

- Web 开库失败仍是静默白屏，没有用户可见的错误提示 → 需要启动失败兜底屏。
- Web 窄窗（<600）栈导航形态、TC-REG-101 完整链路（详情编辑/完成/搜索/删除回收窗）未走查。
- 多标签页并发写同一 IndexedDB（当前用 dedicated worker + sharedIndexedDb，未压测）。

