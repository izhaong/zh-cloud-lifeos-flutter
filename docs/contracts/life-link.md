# LifeLink（Phase 0 草案）

跨应用互调深链契约。实现包：`packages/life_link`。

## Scheme

```text
lifeos://<domain>/<action>[/<resourceId>][?query]
```

示例：

| URI | 能力 id | 说明 |
|-----|---------|------|
| `lifeos://task/open?id=42` | `task.open` | 打开单条提醒 |
| `lifeos://task/openList/list.personal` | `task.openList` | 打开列表 |
| `lifeos://calendar/viewDay?date=2026-10-22` | `calendar.viewDay` | 日历某日 |

## 规则

1. 不传 access token；互调只传业务资源 ID（首期会话策略 A）
2. 各 Cloud App 自行注册可处理的 capability
3. 解析失败静默忽略或提示「未安装对应应用」

正式冻结版本随 Phase 0 Issue 升版号。
