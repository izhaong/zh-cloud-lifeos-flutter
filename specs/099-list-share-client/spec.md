# 099 清单共享的客户端半面（flutter#570）

## 背景

矩阵 `zh-cloud-docs/lifeos/task/plan/apple-reminders-parity-matrix.md` 行 25
「共享列表（邀请/参与者）」口径 = 「降级：member 协作」，FL 列长期是 `无`。
服务端契约已分两笔落地：zh-cloud-service #587（写侧六端点）与 #589（手机号解析 + 我参与的清单）。
本卡是客户端消费面。

## 依赖方向（为什么端口放 kernel）

`feature_task` **不依赖** `feature_task_cloud`（后者依赖前者）。所以：

- 抽象 `TaskCollabPort` 放 `feature_productivity_kernel/lib/src/ports/`（与 `ReminderRepository` 同目录同规约）；
- Provider `taskCollabPortProvider`（默认 `null`）放 `feature_task/lib/src/providers.dart`；
- 实现 `RestTaskCollabPort` 放 `feature_task_cloud`，由组合根 `apps/life_launcher/lib/main.dart` 注入
  —— 与 `calendarCollabPortProvider` 完全同一条路子。

## 口径（写进断言的那几条）

1. **谁看得见什么**：只有 `role=owner` 能看见邀请输入框、「改角色」「移除」；
   被共享人只看见「退出这份清单」；`status=invited` 的人看见「接受邀请」。
   身份来源是 `whoAmI()`（读会话，不发网络）+ 成员表里的 owner 行——
   本地 `ReminderList` 没有 owner 列，不能靠它判。
2. **没有服务端编号就不打网络**：`ReminderList.remoteId == null`（本机新建、还没同步过）
   时给一句人话说明。端口里 `_serverId()` 再兜一次，防止别处误调。
3. **失败 ≠ 空态**：业务信封 `code != 0` 必须抛 `TaskCollabException` 并把服务端中文 `msg`
   显示出来；折成空列表会让「无权访问」看起来像「还没有协作者」。
4. **端口未注入**（未登录/离线档）：点入口给说明弹窗，不放置灰占位——
   置灰会让人以为功能已存在（#533 删掉的就是那种坏状态）。

## 明确没做（另立卡）

- **侧栏「与我共享」分区**：`my-lists` 端点已可调用，但共享清单的**内容**在 test 侧仍拉不下来——
  服务端 `LifeosListServiceImpl.getListList` 是 `selectListByOwnerUserId(userId)`，
  同步侧注释也写着「owner_user_id 就是唯一判据（跨用户按不存在处理）」
  （`LifeosTaskSyncApplier.java:304`）。⇒ 成员看不到清单内容，需要服务端先放开可见性。
- 行 26「分配提醒给参与者」：lifeos 侧没有 assignee 端点（只有 Todo 线有），不在本卡。
- 邀请不校验对方是否已在成员表（服务端会判重并回中文错误，UI 直接显示）。
