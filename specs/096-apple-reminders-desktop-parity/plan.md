# Apple Reminders 桌面视觉壳 · 实现计划（PR1）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把桌面提醒事项区域（侧栏彩色智能卡、主列表头/行/分区、详情与设置外观）做到参考图 1:1，保留现有 repository/路由/测试基线。

**Architecture:** 在 `feature_task` 内做 in-place 组件重构：新增 `design/life_tokens.dart` 与共享 `SmartListCard`，替换 `TaskSidebar` 的智能列表行、`_ListHeaderToolbar`、`ReminderRow` 的视觉层；不重写 provider/repository。断点逻辑保持三档；桌面侧栏宽度改为 `clamp(width*0.235, 240, 360)`。

**Tech Stack:** Flutter 3.44 / Dart 3.12、Riverpod、Cupertino/Material、flutter_test、Melos。

**Spec:** `specs/096-apple-reminders-desktop-parity/spec.md`

## Global Constraints

- 不改 `ReminderRepository` 契约；PR1 只动 UI/组件与必要 props。
- 保留现有测试 key：`sidebar_add_list`、`sidebar_toggle`、`sidebar_settings`、`tag_chip_*`、`group_*`、`list_header_toolbar`、`remaining_count`、`section_*`、`bottom_new_item`、`show_sidebar`。
- 字体不引入文件；颜色/渐变集中在 token；不使用暗色主题。
- 提交信息中文：`<type>(<scope>): <中文描述>`。
- 全量门禁：`dart run melos exec -- flutter analyze --fatal-infos` + `dart run melos exec --dir-exists=test -- flutter test`。
- 每次测试后若 `pubspec.lock` 被镜像改写，提交前 `git checkout -- pubspec.lock`。

---

### Task 1: 设计 token + 共享智能卡

**Files:**
- Create: `packages/feature_task/lib/src/design/life_tokens.dart`
- Create: `packages/feature_task/lib/src/widgets/smart_list_card.dart`
- Test: `packages/feature_task/test/smart_list_card_test.dart`

**Interfaces:**
- `LifeTokens`: static colors/gradients; `smartGradient(String id)`, `smartForeground`, `sidebarBg`, `separator`, `overdue`, `secondaryLabel`.
- `SmartListCard({required ReminderList list, required bool selected, required VoidCallback onTap, bool compact = false})` with keys `smart_card_<id>`.

- [ ] **Step 1: Write failing test** — pump a `SmartListCard` for `smart.today` in a 320-wide box; expect `smart_card_smart.today`, text `今天`, count `3`, and a `DecoratedBox`/`Container` with a `BoxDecoration.gradient`; tap invokes callback.
- [ ] **Step 2: Run** — `cd packages/feature_task && flutter test test/smart_list_card_test.dart` → fail (widget missing).
- [ ] **Step 3: Implement tokens + card** — gradient map per spec §3.2; white foreground; 10px radius; padding 10–12; icon 18, count 20/w600, label 13/w600. Selected adds 2px blue border.
- [ ] **Step 4: Run** → pass.
- [ ] **Step 5: Commit** — `feat(task): 新增设计 token 与智能列表卡片`.

### Task 2: 桌面侧栏改为彩色卡网格 + 我的列表图标

**Files:**
- Modify: `packages/feature_task/lib/src/widgets/task_sidebar.dart`
- Modify: `packages/feature_task/lib/src/task_scaffold.dart`（`_TwoPane`/`_ThreePane` 侧栏宽度）
- Test: `packages/feature_task/test/task_sidebar_cards_test.dart`（新建）

**Interfaces:**
- `TaskSidebar` 新增可选 `double width`? 不：宽度由宿主 `SizedBox` 控制。
- `TaskSidebar` 内部：智能区 = `GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollable, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.15)`，`SmartListCard`；`我的列表` = `_MyListRow`（24 圆角方块 + glyph + 标题 + 计数 + 选中背景）。
- 顶部工具条保留三键；`Material` 底色 `LifeTokens.sidebarBg`。
- 标签区保留 chip。
- 建议列表：若 `mine` 中无 `listType == grocery`，渲染 `SuggestedListRow`（key `suggested_grocery`）；点击 `ReminderList.createGroceryList(id: 'list.grocery.${DateTime.now().millisecondsSinceEpoch}', title: '日常采购')` 并 `upsertList`。
- 宽度：`_TwoPane`/`_ThreePane` 用 `LayoutBuilder` 计算 `clamp(maxWidth*0.235, 240, 360)`；`_TwoPane` 最小 240，`_ThreePane` 同。

- [ ] **Step 1: Write failing tests** — pump `TaskSidebar` at 320 宽，断言 7 张卡（`smart_card_*`）、2 列（`find.byType(GridView)`）、`我的列表` 行 key、建议行 key；点击建议行后仓库出现 grocery 列表且行消失。
- [ ] **Step 2: Run** → fail.
- [ ] **Step 3: Implement** — 替换 `_SidebarTile` 智能区；新增 `_MyListRow`、`SuggestedListRow`；保留 group/flat 逻辑；更新 `task_scaffold.dart` 宽度。
- [ ] **Step 4: Run sidebar tests + `task_scaffold_test.dart`** → pass；修旧测试中 `find.textContaining('今天').first` 误点卡片的用例（改为 `find.byKey(ValueKey('section_今天'))`）。
- [ ] **Step 5: Commit** — `feat(task): 桌面侧栏改为彩色智能卡网格`.

### Task 3: 主列表头 + 分区头 + 新提醒幽灵行

**Files:**
- Modify: `packages/feature_task/lib/src/task_scaffold.dart`
- Test: `packages/feature_task/test/list_header_visual_test.dart`（新建）

**Interfaces:**
- `_ListHeaderToolbar` 改为：左标题（列表色 28/w700，key `list_large_title` 保留）+ 下方 `N 项完成 · 清除`；右侧大计数 `remaining_count`（仅 `!list.isSmart` 显示）+ 显示/排序；移除标题下的 `remaining_count`。
- 新增 `_GhostNewRow`（key `ghost_new_item`）在非 compact 列表顶部，点击 `_openNewItemDialog`；compact 保留 `bottom_new_item`。
- 分区头样式：13/w600 灰 + chevron；key `section_<title>` 保留。

- [ ] **Step 1: Write failing tests** — 用户列表宽 1280：标题色 = `list.colorArgb`、`remaining_count` 在标题右侧、`done_count`/`clear_completed` 行为不变；非 compact 有 `ghost_new_item`，compact 无；点击 ghost 出草稿。
- [ ] **Step 2: Run** → fail.
- [ ] **Step 3: Implement** — 调整 `ListContentPane` 的 header 结构；`_GhostNewRow`；样式 token。
- [ ] **Step 4: Run** → pass；更新 `ui_walkthrough_test` 的分区头定位。
- [ ] **Step 5: Commit** — `feat(task): 主列表头与分区样式对齐参考图`.

### Task 4: 任务行样式（列表名/逾期红/时间）

**Files:**
- Modify: `packages/feature_task/lib/src/widgets/reminder_row.dart`
- Modify: `packages/feature_task/lib/src/task_scaffold.dart`（传 `listName`）
- Modify: `packages/feature_task/lib/src/widgets/reminder_detail_pane.dart`（子任务行兼容）
- Test: `packages/feature_task/test/reminder_row_visual_test.dart`（新建）

**Interfaces:**
- `ReminderRow({..., String? listName})`；副标题 = `[listName, dueText, ...meta].join(' · ')`；`dueText` 逾期（`dueAt < 今天零点`）用 `LifeTokens.overdue`；今天有时间的显示 `HH:mm`，无时间显示 `今天`；其他显示 `M月d日`。
- 旗标未选中时 `Color(0xFFC7C7CC)` 且 `opacity` 由 hover/compact 控制；保持 `row_flag_<id>` key。

- [ ] **Step 1: Write failing test** — 种一条 `list.personal`/`dueAt=yesterday 09:00`/`listName='个人'`；断言副标题含「个人 · 」且 `Text` 颜色为红色；今天 14:30 显示 `14:30`。
- [ ] **Step 2: Run** → fail.
- [ ] **Step 3: Implement** — 传入 `listName`（`ListContentPane` 从 `widget.list.title` 取；子任务传父列表名）；颜色/时间格式。
- [ ] **Step 4: Run** → pass；更新旧测试中断言副标题的文案。
- [ ] **Step 5: Commit** — `feat(task): 任务行补列表名与逾期红字`.

### Task 5: 详情/设置/列表编辑外观

**Files:**
- Modify: `packages/feature_task/lib/src/widgets/reminder_detail_pane.dart`
- Modify: `packages/feature_task/lib/src/widgets/task_settings_sheet.dart`
- Modify: `packages/feature_task/lib/src/widgets/new_list_dialog.dart`
- Test: `packages/feature_task/test/detail_visual_test.dart`（新建）

**Interfaces:**
- 详情：白底分组卡（圆角 12、1px 分隔、icon 18 蓝），标题/备注/日期/重复/结束日期/旗标/标签/优先级/列表/子任务行顺序不变；key 不变。
- 设置：分组白卡 + switch 行；字段与 key 不变（持久化留 PR2）。
- 新建列表：复用 `showNewListDialog`，样式对齐参考图（名称/颜色/图标/类型）；`ListEditSheet` 先不新增行为，只改外观。

- [ ] **Step 1: Write failing tests** — 详情面板出现 `detail_section_identity`（新 key）且颜色/圆角断言；设置出现 `settings_group`；新建列表 dialog 视觉 key。
- [ ] **Step 2: Run** → fail.
- [ ] **Step 3: Implement** — 只改样式，不改字段逻辑。
- [ ] **Step 4: Run** — `detail_edit_interactions_test.dart` + `wireframe_placeholder_paths_test.dart` + 新测试全绿.
- [ ] **Step 5: Commit** — `feat(task): 详情与设置外观对齐参考图`.

### Task 6: 紧凑首页复用 + 视觉验收

**Files:**
- Modify: `packages/feature_task/lib/src/task_scaffold.dart`（`_CompactPane` 用共享 `SmartListCard`、`_MyListRow`）
- Test: `packages/feature_task/test/compact_home_visual_test.dart`（新建）
- Docs: `docs/test-traceability.md`（若在 feature_task 仓内无此文件，则跳过；PR2 统一回填）

- [ ] **Step 1: Write failing test** — 390 宽首页：`smart_card_smart.today` 存在且渐变非白；我的列表行有彩色图标；建议列表行存在。
- [ ] **Step 2: Run** → fail.
- [ ] **Step 3: Implement** — 删除 `_SmartCard` 私有实现，改用共享组件；首页 GridView 参数与桌面一致（ratio 2.15）。
- [ ] **Step 4: Run** — 全量 `flutter test` + analyze；在 390/900/1280 起 Web 真 UI 截图；与 `ref-macos-reminders-main-sidebar.png` 并排核对。
- [ ] **Step 5: Commit** — `feat(task): 紧凑首页复用桌面智能卡与列表行`.

---

## 验收清单（PR1）

- [ ] `dart run melos exec -- flutter analyze --fatal-infos` → 0 issues
- [ ] `dart run melos exec --dir-exists=test -- flutter test` → 全绿
- [ ] 390/900/1280 真 UI 截图：侧栏卡片、建议列表、我的列表、主列表头/行/分区、详情、设置
- [ ] 与参考图并排核对（颜色/间距/字号/层级）
- [ ] 旧测试 key 保留；新增测试覆盖卡片/侧栏/头/行/详情
- [ ] `pubspec.lock` 未被镜像改写提交
- [ ] PR 正文附截图与 `Refs #96`、`Refs #89`
