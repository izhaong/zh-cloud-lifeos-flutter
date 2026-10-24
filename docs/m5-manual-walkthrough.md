# M5 多端回归 · 手动走查清单（TC-REG-101/103/104/106/109/110/111）

> 执行环境：macOS 桌面（flutter run -d macos）+ Chrome（flutter run -d chrome）为必跑；
> Android/iPad 真机如具备则加跑，不具备则记录「设备不可用」并在回归报告注明。
> 每项走完在 [ ] 打 x，异常截图归档 `zh-cloud-docs/lifeos/04_测试与质量/m5-regression/`。

## TC-REG-101 平台矩阵 × 核心链路（P0）

每平台按序执行，任何一步崩溃/白屏即 FAIL：

- [ ] **macOS**：新建列表 → 新建提醒 → 详情编辑（备注/优先级/旗标）→ 完成（圆圈划线）→ 搜索命中 → 删除（回收窗可见）
- [ ] **Web(chrome 宽屏)**：同上链路（三栏：侧栏|列表|inspector）
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

- [ ] 宽屏直接刷新 `/` → 恢复任务首页
- [ ] 深链 `/list/smart.today` → 直接进「今天」视图
- [ ] 窄窗深链同上 → 栈导航形态正确
- [ ] 刷新后数据在（本地库不丢）

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
| TC-REG-101/103/104/106/109/110/111 | 手动（本清单） | 待设备走查归档 |

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
