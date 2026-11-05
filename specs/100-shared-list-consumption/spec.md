# 100 共享清单的侧栏与「点开」读路径（flutter#599 / #600）

## 背景

`TaskCollabPort.mySharedLists()`（specs/099）有端口、有 REST 实现、有端口测，
但 **UI 消费者为零**：侧栏只有 `splitPinnedUserLists` 那几节。#599 要把它接上，
#600 要让它点得开——列出来点不开比不列更糟，所以两卡一起做、一起发。

## 路线裁决（ADR：#600 选 B，不选 A）

- **A 物化 + 禁出站**：把共享清单连条目拉进本地 Drift，打「非本人 owner」标记，出站不入 outbox。
  代价是同步协议扩围（服务端要能按 listId 向成员增量导出），且要过
  `list_view_preference_scope.dart` 那套作用域口径——动的面大，新洞的机会也多。
- **B 直连只读视图**（本卡采用）：选中共享清单时不走 Drift 流，直接
  `GET /app-api/lifeos/task/task/page?listId=`，渲染成只读视图。
  改动小、结构上不可能产生属于本人的 outbox 变更。
- **为什么不选 A**：#600 的硬判据是「这一趟不得产生任何属于本人的 outbox 变更」。
  B 是靠类型系统保证的（只读视图拿的是 `TaskSharedItem`，不是 `ReminderItem`，
  没有任何一条路能把它写回 `reminderRepositoryProvider`）；
  A 是靠人记得加标记保证的。少造新洞优先。
- **B 接受的差异**：共享清单没有离线能力；且「可编辑」角色在本视图里也只显示不写。
  写侧要接，得另开一条直连 REST 的写通道并明确不落 outbox——那是另一张卡的量级，
  已按 §8 留待立单，不在本卡偷渡。

## 口径（写进断言的那几条）

1. 侧栏「与我共享」一节只在 `mySharedLists()` 有返回时出现；
   端口为 `null`（离线/未登录）或抛错 ⇒ **整节不显示**，也不给「加载失败」噪声。
2. 行 key `sidebar_shared_<listId>`，副标题用 `taskShareRoleLabel(role)`
   ——与 `ListShareSheet` 同一份中文口径，不再各写一套。
3. 点行 ⇒ 主区渲染 `SharedListPane`（key `shared_view_<listId>`），
   条目来自 `sharedListTasks()` 直连读侧（key `shared_item_<id>`）。
4. 只读视图里没有任何可写入口：无输入框、无「新提醒事项」、无可点的 `CupertinoButton`。
5. 反向探针挂 `sharedListByIdProvider` 的 `listId` 过滤上：摘掉它，
   自己的清单也会被渲染成共享视图，用例当场红。

## 依赖方向（沿用 specs/099）

抽象与新类型 `TaskSharedItem` 放 kernel；Provider 放 `feature_task/lib/src/providers.dart`；
REST 实现放 `feature_task_cloud`；组合根注入。`feature_task` 不依赖 `feature_task_cloud`。

## 端点更正

#600 正文猜的是 `/app-api/lifeos/task/item/page`；现读服务端
`AppLifeosTaskItemController` 的 `@RequestMapping("/lifeos/task/task")` + `/page`，
实际路径是 `/app-api/lifeos/task/task/page`，本卡按实际路径接，端口测钉住它。
