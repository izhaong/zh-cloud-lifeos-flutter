# LifeOS 任务模块 · UI/交互测试 Traceability 矩阵

> 工作树：`/Users/zhonghao/code/zh/worktrees/lifeos-task-flutter`
> 分支：`feat/76-task-kr-cases`
> 生成日期：2026-10-26
> 门禁基线：`dart run melos exec --dir-exists=test -- flutter test` → 257/257 全绿（改动前）
> 本文档：把「UI 视图 / 交互 / 功能点」→「测试文件 / TC ID / 操作路径 / 结果」一一对应，并如实标注覆盖缺口与合并覆盖。

---

## 1. 矩阵说明

- **强断言**：每条交互路径都由 `pumpWidget → tap / enterText → pumpAndSettle → expect` 真实执行，且断言不因 key 缺失被跳过。
- **软断言红线**：测试里出现 `if (finder.evaluate().isNotEmpty) { … }` 包裹断言 = 断言空转（可能“假通过”），必须消除。历史案例见 §5。
- **合并覆盖**：一个 `testWidgets` 覆盖多个 TC ID 属合理合并，不算遗漏，但需确认每项都有独立断言。
- **单测 vs 交互测试**：kernel / drift / cloud / life_link 多为 Dart 单测（不涉及 tap / enterText），已在 §4 单列。

---

## 2. feature_task（任务列表主包）· UI 交互矩阵

| 功能 / 视图 | 测试文件 | TC ID | 操作路径（实际走一遍） | 结果 |
|---|---|---|---|---|
| 三档断点响应式（599/600/1199/1200）+ 无残留叠加 | `test/tc_reg_regression_test.dart` | TC-REG-102 | 窗口依次设 599/600/1199/1200，断言 `sidebar_toggle` 出现/消失；跨档断言侧栏 ≤1 | ✅ |
| medium vs expanded：选条目出 inspector（1200）/不出（1199） | `test/tc_reg_regression_test.dart` | TC-REG-102（中） | 1199 点行 → `详细信息` findsNothing；1200 点「买牛奶」→ findsOneWidget | ✅ |
| 生命周期：重 pump 数据不丢、流不断流 | `test/tc_reg_regression_test.dart` | TC-REG-108 | 种子 → pump → 整树重 pump → 数据在；再 upsert → 新条目出现 | ✅ |
| 空列表：列表色大标题 + 空态引导 + 底栏「新提醒」 | `test/tc_reg_regression_test.dart` | M5 实机差距批 | pump 空列表 → 断言 `list_large_title`/橙色标题/`empty_new_hint` | ✅ |
| 空列表点工具栏＋出草稿行，不吞掉 | `test/tc_reg_regression_test.dart` | M5 实机差距批 | 点 `toolbar_new_item` → `TextField` 可见、`没有提醒` 消失 | ✅ |
| 负向门禁：无 iCloud/Outlook/分配事项/建议列表/FAB/NavigationBar | `test/tc_reg_regression_test.dart` | TC-REG-107 | 375×812 + 1366×1024 各 pump → 全部 findsNothing | ✅ |
| 侧栏隐藏 → 主区铺满 → 再显示恢复 | `test/audit_fix_real_interactions_test.dart` | TC-UI-304 | 点 `sidebar_toggle` → `智能列表` 消失、`show_sidebar` 出现；再点恢复 | ✅ |
| Inspector：点行出现、点另一行就地切换、标题重置 | `test/audit_fix_real_interactions_test.dart` | TC-UI-307 | 无 inspector → 点「买牛奶」→ 出现 → 点「写 LifeOS 基建」→ 唯一且标题已重置 | ✅ |
| 切行后保存不覆盖错条目 | `test/audit_fix_real_interactions_test.dart` | TC-UI-307b | 点两条后点「完成」→ 断言 id=2 仍「写 LifeOS 基建」、id=1 仍「买牛奶」 | ✅ |
| 宽屏负向：无第二套导航/TabBar/未实现文案 | `test/audit_fix_real_interactions_test.dart` | TC-UI-N3 | 宽屏 pump → NavigationBar/BottomNavigationBar/TabBar/iCloud/… findsNothing | ✅ |
| ⋯编辑占位 SnackBar 全文锁定 | `test/audit_fix_real_interactions_test.dart` | TC-UI-207 | 点 `home_edit_placeholder` → pump → 断言「编辑列表 · 规划占位」 | ✅（占位，见 §6） |
| 今日视图新建项出现（dueAt=今天） | `test/today_view_new_item_test.dart` | 回归（用户实测反馈） | 底栏新建 → 输入 → done → 断言条目出现、空态让位、dueAt≠null | ✅ |
| 计划视图新建项带 dueAt | `test/today_view_new_item_test.dart` | 回归 | 同上在 `smart.scheduled` → 断言仓库 dueAt≠null | ✅ |
| 搜索框：宽屏出现 / 紧凑不出现 | `test/search_ui_test.dart` | TC-UI-202 | 375 → `toolbar_search` findsNothing；1366 → findsOneWidget | ✅ |
| 搜索按标题过滤（大小写不敏感） | `test/search_ui_test.dart` | TC-UI-202 | 输入「牛奶」→「买牛奶」出现、「写 LifeOS 基建」消失 | ✅ |
| 搜索匹配备注与标签；清空全回来 | `test/search_ui_test.dart` | TC-UI-202 | 种含 notes/tags → 搜「老板」→「交报告」出现；清空 → 全部回来 | ✅ |
| 无匹配显示「无匹配结果」 | `test/search_ui_test.dart` | TC-UI-203 | 搜不存在的词 → 断言「无匹配结果」 | ✅ |
| 手动分区：按元数据序、未分区兜底、折叠、互斥 | `test/manual_sections_ui_test.dart` | TC-UI-110 | upsert Section/Item → 断言分区头顺序、条目落桶、点分区头折叠、手动模式不出日桶、无分区回退日桶 | ✅ |
| 首页计数：计划 3/全部 4/已旗标 1；点入 smart.* 命中集 | `test/smart_list_semantics_test.dart` | TC-UI-102/103/104 | pump 首页断言计数；分别 pump scheduled/all/flagged → 断言命中/未命中 | ✅ |
| 侧栏分组折叠/展开、交错 groupName 聚合、无分组平铺 | `test/list_grouping_ui_test.dart` | TC-UI-118 | 点 `group_工作` 折叠 → 组内行消失、他组不动；再展开；交错 B,A,B → 唯一组头 | ✅ |
| 删除 → 最近删除视图可见 → 恢复回原列表 | `test/trash_and_tags_test.dart` | TC-UI-109 | deleteItem → 列表内消失 → 换 smart.trash → 可见 → 点 `restore_i1` → 回 list.a | ✅ |
| 标签浏览器：chip 出现，点选按标签过滤 | `test/trash_and_tags_test.dart` | TC-UI-117 | 种含 tags → 断言 chip → 点 `tag_chip_工作` → 命中/过滤 | ✅ |
| 底部工具条「新提醒」三档宽度；草稿一次落库；空标题零写入 | `test/phase2_ui_test.dart` | TC-UI-201 | 三档 pump 断言；点 → 输入 → done → upsertCount=1；空标题 → 未增 | ✅ |
| 旗标点击即时切换并从 smart.flagged 流出 | `test/phase2_ui_test.dart` | TC-UI-106 | 点 `row_flag_1` → 断言 `watchItems(smart.flagged)` 为空 | ✅ |
| 添加列表弹窗：提交后首页即时出现新列表 | `test/phase2_ui_test.dart` | TC-UI-206 | 点「添加列表」→ 输入「购物」→「完成」→ 断言出现且仓库含 | ✅ |
| 全仓无 FloatingActionButton（Reminders IA 门禁） | `test/phase2_ui_test.dart` | TC-UI-N1 | pump → FAB findsNothing | ✅ |
| 详情面板添加子任务 → 列表行呈现缩进子任务 | `test/subtask_ui_test.dart` | — | 详情添加子任务 → 断言列表行缩进 | ✅ |

### 2.1 详情编辑链（真编辑能力，本批次新增强断言）

真实可编辑字段：**标题 / 备注 / 标签 / 旗标 / 优先级 / 重复+结束日期 / 移动列表 / 子任务**，保存 = `copyWith` 全量回写 `upsertItem`。对应文件：`test/detail_edit_interactions_test.dart`（新增）。

| 功能 | TC ID | 操作路径（实际走一遍） | 结果 |
|---|---|---|---|
| 详情编辑备注 → 保存 → 仓库 notes 回写 | TC-UI-113a | 宽屏 `selectedItemId` 开 inspector → 断言「详细信息」+ 备注框存在 → enterText「重要会议备注」→ 点 AppBar「完成」→ 断言仓库 `notes` | ✅ |
| 多字段一次编辑 → 保存 → 逐字段回写 | TC-UI-113b | 改标题/备注/标签/旗标开关/优先级「高 !!!」→ 保存 → 断言 `title`/`notes`/`tags`/`isFlagged`/`priority=9` | ✅ |
| 备注可被搜索命中 | TC-UI-113c | 预置带备注 item + 干扰 item → 搜「会议」→ 命中出现、未命中过滤 | ✅ |
| 详情重复区出现结束日期行且默认永不 | TC-UI-319 | 种 `recurrence='daily'` → 开详情 → 断言 `recurrence_until_row`/「结束日期」/「永不」 | ✅ |
| 列表编辑入口 = 占位 SnackBar | TC-UI-207 | 首页点 `home_edit_placeholder` → 断言「编辑列表 · 规划占位」 | ✅（占位，见 §6） |

---

## 3. apps/life_launcher（壳）· UI 交互矩阵

| 功能 | 测试文件 | 操作路径 | 结果 |
|---|---|---|---|
| 壳启动冒烟：任务 Tab + 智能列表 | `test/smoke_test.dart` | pump `LifeLauncherApp` → 断言「列表」「今天」「更多」 | ✅ |
| 底栏顺序任务/日历/习惯/更多，更多恒最右 | `test/smoke_test.dart` | 断言 NavigationDestination labels | ✅ |
| 编辑态：−移出/＋加回写即生效落 mock 偏好；底栏实时变化 | `test/smoke_test.dart` | 点更多/编辑 → `unpin_task`/`pin_task` → 断言偏好 + 底栏标签实时变化 | ✅ |
| 编辑态更多行无 −/手柄（不可移除） | `test/smoke_test.dart` | 断言 `unpin_more`/`pin_more` findsNothing | ✅ |
| 徽标：override {task:3} → Tab 角标；默认无徽标 | `test/smoke_test.dart` | pump 带 badges → 断言 Badge/「3」；默认 → Badge findsNothing | ✅ |
| 占位应用可固定/打开与正式应用一致 | `test/smoke_test.dart` | pump →「日历」可见；点更多 → 断言含「占位」 | ✅ |
| 紧凑竖屏点列表：壳内推入且底栏常显 | `test/smoke_test.dart` | 点「个人」→ NavigationBar findsOneWidget、NavigationRail findsNothing | ✅ |
| Pad 宽屏：左侧 NavigationRail，无底栏 | `test/smoke_test.dart` | pump 1024×768 → 断言 NavigationRail 可见、NavigationBar 不见 | ✅ |
| Tab 切日历出现工具栏不进任务区 | `test/tc_cal_ui_311_shell_calendar_test.dart` | TC-CAL-UI-311/001 | ✅ |
| 冷启动未登录：直达任务区，无强制登录弹窗 | `test/tc_sync_101_cold_start_test.dart` | TC-SYNC-101 | ✅ |

---

## 4. 单测层（非 UI 交互，均通过）

| 包 | 用例数 | 说明 |
|---|---|---|
| feature_productivity_kernel | 65 | TC-KR-116/117（本地 id 前缀、删智能列表不级联）、kernel/manual_sections/occurrence_expander/smart_urgent/completed/list_type/contract_fields/recycle_window/toggle_completed_at 等 |
| feature_productivity_drift | 44 | Drift 仓库单测（内存/临时库，不连真数据库） |
| feature_task_cloud | 27 | sync_gaps/auth_port/secure_session_store/sync_port/login_page（Noop/mock，不发真网络） |
| life_link | 9 | life_link_uri 深链契约单测 |

---

## 5. 已消除的“空转断言”（假通过）

**案例：`test/ui_walkthrough_test.dart` 原 TC-UI-113 备注编辑**
- 原代码：`final notesField = find.byKey(const ValueKey('detail_notes')); if (notesField.evaluate().isNotEmpty) { …断言… }`
- 问题：`ReminderDetailPane` **没有 `detail_notes` 这个 key**（备注 `TextField` 只设了 `hintText: '备注'`），`evaluate()` 恒为空 → **整个断言被跳过**，测试“绿”了但什么都没测。
- 修复：改用 `find.widgetWithText(TextField, '备注')` 定位，去掉 `if` 包裹，改为强断言（备注框必须存在、仓库 `notes` 必须回写、搜索必须命中）。

> 审计方法：`rg -n "evaluate\(\).isNotEmpty" packages/feature_task/test/` 扫出所有软断言包裹。

---

## 6. 覆盖缺口（已知，如实标注）

| 缺口 | 现状 | 处置建议 |
|---|---|---|
| **列表编辑页（TC-UI-207）** | 真编辑页 UI **未落地**，`home_edit_placeholder` 仅弹占位 SnackBar「编辑列表 · 规划占位」 | 占位断言已锁定（见 §2.1）；真编辑页落地后须更新该断言（测试注释已注明会强制失败） |
| **习惯（habit）功能** | 仅作为 Tab 标签出现，**无 habit 增删完成 widget 测试** | 用户确认 habit 尚未实现，**暂不补测**；实现后再补 |
| 子任务后续交互（完成/删除/排序） | `subtask_ui_test.dart` 仅覆盖“添加后列表行缩进” | 后续补勾选/删除/排序强断言 |
| 真机后台/前台与杀进程恢复 | TC-REG-108 用“整树重 pump”近似，注释已注明属手动清单（设备项） | 保留 widget 级近似，真机项待设备清单 |

---

## 7. 门禁建议

- **新增/修改 UI 测试必须强断言**：不得用 `if (finder.evaluate().isNotEmpty)` 包裹关键断言。
- **合并覆盖允许**，但每项 TC 需有独立 `expect`。
- **占位功能**（如 TC-UI-207）的测试必须锁占位文案，落地时强制更新。
- 全量门禁：`dart run melos exec --dir-exists=test -- flutter test`，7 包 257 用例基线全绿（改动前）。