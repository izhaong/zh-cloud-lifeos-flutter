# Apple Reminders 桌面 1:1 复刻 Spec

- 状态：Draft（2026-10-26）
- Issue：`#96`（Refs `#89` 差距清单）
- 参考：
  - `zh-cloud-docs/lifeos/task/wireframes/ref-macos-reminders-main-sidebar.png`（图2，1024×582）
  - 用户提供的 Apple Reminders 高分辨率截图（3064×1742，2x；用于取色/量距）
- 目标仓：`zh-cloud-lifeos-flutter`，分支 `feat/96-apple-reminders-parity`
- 范围：桌面（macOS）优先；Pad/手机下一轮复用同一套组件

## 1. 目标

保留 LifeOS 最左应用轨（任务/日历/习惯/更多），把右侧提醒事项区域按 Apple Reminders 图2 做到**视觉 1:1、交互可信**：侧栏彩色智能卡、建议列表、彩色列表图标；主列表彩色标题/计数/工具条/分区/任务行；详情 inspector、列表编辑与设置弹层；必要的日期时间编辑、删除、今天含过期、时间分组。

“1:1”指布局、层级、间距、圆角、配色、字号/字重、图标语义与状态一致；不引入 Apple 专有字体文件，使用系统 SF 字体回退。

## 2. 交付拆分

### PR 1 · 桌面视觉壳（本 spec 的主交付）

- 设计 token（颜色/渐变/字号/间距/圆角/分隔线）
- 侧栏：2 列彩色智能卡（今天/计划/全部/已旗标/紧急/完成/分配事项）、建议列表、我的列表彩色图标、标签
- 主列表：彩色大标题、`N 项完成 · 清除`、大计数、显示/分享/排序/＋/搜索、分区头、任务行（列表名＋日期、逾期红字）、新提醒幽灵行
- 详情 inspector、列表编辑/设置弹层外观
- 1024/1280 golden 基线 + 真 UI 截图

### PR 2 · 交互补齐（让参考图真实成立）

- `smart.today` 含过期；时间分组（逾期 / 上午 / 下午 / 今晚）
- dueAt 日期/时间编辑（日期选择 + 时间选择 + 全天开关 + 清除）
- 左滑（紧凑）/右键菜单（桌面）/详情菜单删除，进最近删除
- 列表改名/颜色/类型；设置偏好持久化；建议列表（日常采购模板）；分配事项空智能列表
- 最近删除计数修复；完成撤销横幅超时/切页清除

## 3. 视觉系统

### 3.1 布局与尺寸

以参考图 2x 截图量得（CSS 值 = 原图 / 2）：

| 元素 | 参考值 | 实现 |
|---|---|---|
| 窗口 | 1532×871 CSS | 自适应 |
| 侧栏宽 | ≈360 CSS（23.5%） | `clamp(width * 0.235, 240, 360)`；1024→240，1280→300，1532→360 |
| 卡片网格 | 2 列，327×120 px（163.5×60 CSS），列距 13 px（6.5 CSS），外边距 44 px（22 CSS） | 2 列 Grid，gap 8，padding 16–22，卡片最小高 56 |
| 卡片圆角 | ≈20 px（10 CSS） | 10–12 |
| 建议列表行 | 高 ≈44 px（22 CSS） | 40–44 |
| 我的列表行 | 图标 48×48 px（24 CSS），行高 ≈64 px（32 CSS） | 24 图标，32–36 行高 |
| 主列表标题 | 大标题，蓝色/列表色 | 28–30，w700 |
| 任务行 | 高 ≈88 px（44 CSS） | 44–48 |
| inspector | 参考图未展开；按现有 320 宽 | 320 |

### 3.2 颜色 token（从高分辨率参考图取样）

| Token | 值 | 用途 |
|---|---|---|
| `systemBlue` | `#007AFF` / 标题取样 `#0287FE` | 主强调、今天标题、按钮 |
| `systemRed` | `#FF3B30` | 逾期日期、删除 |
| `systemOrange` | `#FF9500` | 旗标 |
| `systemGreen` | `#34C759` | 完成/建议列表 |
| `labelPrimary` | `#000000`（浅色） | 主文本 |
| `labelSecondary` | `#8E8E93` | 副标题/计数 |
| `separator` | `#E5E5EA` | 1px 分隔 |
| `sidebarBg` | `#F5F5F5`（取样 245） | 侧栏底 |
| `mainBg` | `#FFFFFF` | 主区 |
| `windowBg` | `#F2F2F7` | 窗体/设置底 |

智能卡渐变（顶部→底部，取样近似）：

| 卡 | 顶部 | 底部 | 文本 |
|---|---|---|---|
| 今天 | `#82B5EE` | `#74AEEB` | 白 |
| 计划 | `#F09291` | `#EE8684` | 白 |
| 全部 | `#6C6C6C` | `#5E5E5E` | 白 |
| 已旗标 | `#F4BE93` | `#F4B987` | 白 |
| 紧急 | `#F08CA5` | `#EF809D` | 白 |
| 完成 | `#979DA3` | `#8A9096` | 白 |
| 分配事项 | `#9CD9A6` | `#94D69E` | 白 |

列表/标签颜色沿用 `ReminderList.colorArgb`；列表图标 = 彩色圆角方块 + 白色 glyph（standard=list，grocery=cart），不新增持久字段。

### 3.3 字体

- 系统字体（macOS/iOS 自动 SF；Web 回退 system-ui），不引入字体文件。
- 字号：卡片标签 13/w600，卡片计数 20/w600，主标题 28–30/w700，正文 15–16，副标题 12–13，分区头 13/w600，工具条 13/w500。
- 逾期日期用 `systemRed`；已完成标题删除线 + `labelSecondary`。

### 3.4 表面

- 侧栏底 `sidebarBg`；主区白；分隔 1px `separator`；卡片/弹层圆角 10–16；无重阴影（参考图基本扁平）。
- 侧栏与主区之间 1px 分隔；不画双描边。
- 顶部工具条：新建列表、隐藏侧栏、设置；主区右上搜索 pill、＋、⋯。

## 4. 组件映射

### 4.1 智能卡网格（`SmartListCardGrid`）

- 数据：`watchLists()` 的智能列表 + `smart.assigned`（新增，空过滤）。
- 顺序：今天、计划、全部、已旗标、紧急、完成、分配事项。
- 每卡：左上 glyph（白）、右上计数（白）、左下标题（白）。
- 选中态：卡片外描边或略深遮罩；点击就地切换主区（medium/expanded），compact 进入列表页。
- 复用现有 `_SmartCard`，改为支持渐变色 + 白色前景 + 可配置宽度；删除 compact 专用副本。

### 4.2 建议列表（`SuggestedListRow`）

- 条件：设置「建议列表」开 + 不存在 grocery 列表。
- 显示：绿色圆形 cart 图标 + `建议列表：日常采购` + 绿色 ＋。
- 点击：`ReminderList.createGroceryList` 建「日常采购」，随后行消失。
- 真实数据，不做静态假卡；无 grocery 模板时隐藏。

### 4.3 我的列表

- 行：24 彩色圆角方块 + 白色 glyph（list/cart）+ 标题 + 右侧未完成计数。
- 选中态：`systemBlue` 10–12% 背景，不改变文字颜色。
- 分组头保留（列表分组折叠）。

### 4.4 标签

- 侧栏「标签」区：小圆点 + 标签名 + 计数；点击写全局搜索词（沿用现有管线）。
- 与参考图的层级一致（建议列表/我的列表之后）。

### 4.5 主列表头与工具条

- 顶部：彩色大标题（列表色；智能列表用 systemBlue），标题下 `N 项完成 · 清除`（仅已完成>0 显示清除）。**只有自有列表与 `smart.completed` 有这一行**；今天/计划/全部/旗标/紧急等智能视图没有（Apple 实测，#676）。
- 右侧：大计数（用户列表；智能列表计数在卡片，不重复）、`显示▾`、分享（占位/禁用或隐藏）、`排序▾`、`＋`、搜索 pill、`⋯`。
- 参考图工具条在右上；主区内容左对齐。
- 移除标题下方的大计数（今天/智能列表），改为卡片计数 + 列表头计数。

### 4.6 分区

- 分区头：小号灰色标题 + 右侧 chevron；折叠为内存态。
- Today：`已过期` / `上午` / `下午` / `今晚`（第二步；PR1 先保留现有 已过期/今天/明天/日期 但样式对齐）。
- 用户列表：手动分区 > 日桶；无日期最后。
- “新提醒事项”幽灵行置顶（桌面/medium）；compact 保留底部工具条。

### 4.7 任务行

- 布局：完成圆圈（22）| 标题（16）| 副标题（列表名 · 日期/时间/重复/标签）| 右侧旗标/优先级。
- 副标题：列表名 + `·` + 日期；逾期日期红色；今天显示时间（有 dueAt 时间时）。
- 旗标仅在已旗标时着色；未旗标 hover 显示（桌面），compact 常显弱化。
- 点击行：expanded 开 inspector；medium 开详情；compact 进详情页。

### 4.8 详情 inspector

- 宽 320；顶部「详细信息」+ 完成；标题/备注；图标行：日期与时间、重复、结束日期、旗标、标签、优先级、列表、子任务。
- 第二步把「日期与时间」改为可点：日期 picker + 时间 picker + 全天 switch + 清除。
- 子任务行：勾选/删除；新建草稿行。
- 视觉：白底、分组卡片、icon 18–20、行高 44、分隔 1px。

### 4.9 设置与列表编辑

- 设置弹层：480 宽、分组行、Apple 风格 switch；字段：默认列表（可选）、全天提醒时点（时间选择）、完成时标记完成、建议列表、采购清单语言、还原、云同步。
- 列表编辑弹层：名称、颜色、类型、图标；保存回写；桌面从列表标题/⋯进入。
- 偏好持久化：SharedPreferences（PR2）。

## 5. 行为与数据（PR2）

### 5.1 今天含过期

- `smart.today` = 未完成 && (`dueAt` 当天 || `dueAt` < 今天零点)。
- 计数、卡、列表、时间分组一致。
- 更新 `kernel_test` / `ui_walkthrough` / `smart_list_semantics`；与并行分支的 `day_rollover_drift_test` 对齐（跨日后旧的今日项转为过期仍在 Today）。

### 5.2 日期时间编辑

- 详情「日期与时间」点击 → 底部 sheet：
  - 日期 CupertinoDatePicker(mode=date)
  - 时间 CupertinoDatePicker(mode=time)，全天时隐藏
  - 全天 switch（默认 9:00，按文档）
  - 清除（dueAt=null）
- 保存：`upsertItem(item.copyWith(dueAt: ...))`；完成后列表/分组/计数即时刷新。
- 覆盖 TC-UI-112；新增测试。

### 5.3 删除

- compact：`Dismissible` 左滑（红底删除）。
- desktop：行右键 `ContextMenu` / 详情菜单「删除提醒」。
- 删除 = `deleteItem`（级联子任务）→ 最近删除；回收窗 30 天。
- 最近删除视图：行级恢复；已完成删除项也计入侧栏计数（修复 `_recount` 对 smart.trash 的 `!isCompleted`）。

### 5.4 时间分组

- Today：`已过期`（dueAt < 今天零点）→ `上午`（<12）→ `下午`（12–18）→ `今晚`（>=18）；无时间的今天项归 `今天` 或”全天“？按参考图：无时间项归 `今天` 区（不强行分时段）。实现取 `今天` 与时间段并存；参考图时间为准。
- 其他列表保留日桶。

### 5.5 列表编辑与设置持久化

- 列表：名称/颜色/类型；grocery 切换可重建预设分区（确认弹窗）；图标沿用类型默认 glyph。
- 设置：SharedPreferences 持久化默认列表、全天时点、完成标记、建议列表；还原默认。
- 默认列表：新建提醒的落点（当前视图为智能列表时用默认列表）。

### 5.6 建议列表与分配事项

- 建议列表：真实 grocery 模板创建；设置开关控制。
- 分配事项：新增 `smart.assigned` 智能列表，过滤 `assignedTo != null`；当前本地无分配数据 → 计数 0、空态「无分配事项」；不伪造条目。共享/协作后端仍为 M4。

## 6. 非目标

- 共享/邀请/参与者、附件/图片、列表模板、Siri/位置、Apple 字体文件、暗色模式。
- Pad/手机布局本轮不改（下一轮复用组件 + 对应参考图）。
- 不重写 repository/provider 架构；不改服务端契约（除 assigned 字段后续协作）。

## 7. 验收

### PR1

- `dart run melos exec -- flutter analyze --fatal-infos` → 0
- `dart run melos exec --dir-exists=test -- flutter test` 全绿
- golden：1024×768、1280×800 桌面主界面；与参考图并排人工核对
- 真 UI：侧栏卡片/建议列表/我的列表/主列表/详情/设置/搜索；截图存档
- 现有测试中依赖旧布局的 key/文案同步更新，不删断言

### PR2

- TC-UI-101（今天含过期）、TC-UI-109（左滑/右键删除）、TC-UI-112（日期时间编辑）、TC-UI-120（设置持久化）全部真 UI 走通
- 最近删除计数、撤销横幅行为测试
- 全量 analyze/test + 真 UI 截图 + 文档/矩阵回填

## 8. 风险与依赖

- **并行 worktree**：主检出/任务 worktree 正被日历/drift 会话占用；本工作使用隔离 worktree `lifeos-ui-parity`，不碰其未提交改动。
- **day-rollover 冲突**：并行分支的 `day_rollover_drift_test` 锁定「跨日后今天清空」；本 spec 的「今天含过期」需与其对齐（旧今日项转过期仍显示）。
- **golden**：仓库当前无 golden 基建；PR1 引入 `matchesGoldenFile` + 固定字体/尺寸，首版仅桌面两档。
- **交叉评审**：重大 UI/导航方案按 `AGENTS.md` 走 `cursor-agent` × `claude` 只读交叉评审；评审记录写 PR 正文。
- **Apple 字体/素材**：不引入 SF 字体文件；图标用 Cupertino/Material 近似，避免复制 Apple 专有资源。

## 9. 已拍板决策

- **分配事项卡**：新增 `smart.assigned` 真实智能列表（过滤 assignedTo != null）；当前无本地分配数据 → 计数 0 + 空态「无分配事项」，不伪造条目。协作后端仍为 M4。
- **Today 无时间项**：单独 `今天` 分区；有 dueAt 时间且未过期/未跨日的项进 `上午/下午/今晚`；过期项进 `已过期`。
- **分享入口**：PR1 隐藏（不做假按钮），待共享能力落地后再出现。
- **列表图标**：standard=list、grocery=cart 的默认 glyph + 列表色；自定义 icon 字段留到 M4 同步。
- **字体/暗色**：系统字体回退，不引入 SF 字体文件；仅浅色主题。
- **断言策略**：旧测试的 key/文案能保留则保留；布局断言改为按新组件 key，不删覆盖。

## 10. 参考映射（当前代码 → 新组件）

| 当前 | 新 |
|---|---|
| `task_sidebar.dart::_SidebarTile` | `SmartListCardGrid` + `MyListRow` |
| `task_scaffold.dart::_SmartCard`（compact） | 统一 `SmartListCard`（全断点） |
| `_ListHeaderToolbar`（大计数在左） | `ListHeader`（标题/完成计数/右侧大计数/工具条） |
| `reminder_row.dart` | `ReminderRow`（列表名+日期副标题、逾期红、hover 旗标） |
| `_sectionLabel` | `SectionBuilder`（Today 时间段；其他日桶） |
| `reminder_detail_pane.dart` | `ReminderDetailPane`（Apple 分组 + 日期时间编辑） |
| `task_settings_sheet.dart` | `TaskSettingsSheet`（分组行 + 持久化） |
| `new_list_dialog.dart` | `ListEditSheet`（新建/编辑共用） |
