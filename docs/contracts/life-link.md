# LifeLink 跨应用深链契约

> 权威路径：`docs/contracts/life-link.md`（本文件）。实现包：`packages/life_link`。
> 状态：Phase 0 冻结草案；语义变更须升版本号并经交叉评审（§H1）。

## 1. Scheme

```text
lifeos://<domain>/<action>[/<resourceId>][?query]
```

示例：

| URI | 能力 id | 说明 |
|-----|---------|------|
| `lifeos://task/open?id=42` | `task.open` | 打开单条提醒 |
| `lifeos://task/openList/list.personal` | `task.openList` | 打开列表 |
| `lifeos://calendar/viewDay?date=2026-10-22` | `calendar.viewDay` | 日历某日 |

## 2. 能力 ID 命名空间

| 域 | 归属 | 约束 |
|----|------|------|
| `task.*` | 任务 App（feature_task / task_cloud） | 第一方 |
| `calendar.*` | 日历 App（feature_calendar） | 第一方（待拆入） |
| `habit.*` | 习惯 App（feature_habit） | 第一方（待拆入） |
| `cdsm.*` | CDSM | 第一方 |
| `x-<vendor>-*.*` | 第三方应用 | 必须带 `x-` 前缀防撞名（H1 目录审核时校验） |

## 3. 规则（硬约束）

1. **不传 token**：互调不携带 access / refresh token；只传业务资源 ID（首期会话策略 A：各 App 独立登录、同一账号）
2. **不传敏感字段**：只传资源定位符（id/date 等），不传标题正文等业务数据
3. 各 Cloud App 自行注册可处理的 capability；未注册的域解析失败
4. **未安装降级**：目标 App 未安装时静默忽略或引导到目录/商店安装；不得假定同进程
5. 解析实现必须容错：非法 URI 返回 null（见 `LifeLinkUri.tryParse`）

## 4. 版本规则

- 语义变更（删能力/改参数含义）→ 升 major，旧能力至少保留一个 minor 周期
- 纯增能力 → minor
- 实现包 `packages/life_link` 与本文件同步演进；单测覆盖 URI 解析/构造

## 5. OAuth scope 命名空间（Phase 5 实现前置预留）

> 实现属 Phase 5（Member OAuth 第三方 client）；此处只冻命名，防各业务仓自创不一致。

| scope | 说明 | 谁申请 |
|-------|------|--------|
| `profile.read` | 读 member 基础资料（昵称/头像） | 第三方 App 登录 |
| `task.read` | 读任务/提醒（列表+条目） | 第三方 App |
| `task.write` | 写任务/提醒 | 第三方 App（需显式授权） |
| `calendar.read` / `calendar.write` | 日历读写 | 同理 |
| `sync.push` / `sync.pull` | 会员同步（仅第一方 cloud 包使用） | 第一方 |

约束：scope 命名一律 `<domain>.<verb>` 小写；新增须在此表登记后方可进入 OAuth 审核流。
