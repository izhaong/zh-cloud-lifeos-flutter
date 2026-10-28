# App 壳 golden 基线

| 文件 | 尺寸 | 首屏内容 |
|---|---|---|
| `iphone_375_shell.png` | 375×812 | 任务分支的**紧凑概览**（智能列表卡片 + 底栏），不渲染条目标题 |
| `ipad_834_shell.png` | 834×1112 | 任务分支 + 侧栏/列表（**渲染条目标题**） |
| `desktop_1280_shell.png` | 1280×800 | 同上，桌面三栏 |

## 为什么能当门禁

挂钟经 `clockProvider`（`feature_task` 提供，壳直接 override）钉到 `2026-10-26 09:30`；
仓储侧同步设 `nowForTest`，避免 `smart.today` 过滤与分组时钟脱节（#333 的教训）。

## 敏感性实测（两种探针都跑过）

| 探针 | 结果 |
|---|---|
| 改首屏条目标题「周报」→「周报（改）」 | **834 / 1280 红**，375 不红（该宽度不渲染标题） |
| 多加一条待办 | **1280 与另一档红**，375 不红（同上） |
| 改徽标计数 3→9 | **不红**——徽标画的是点，3 与 9 像素相同（探针选错了，记下来） |

即：**834 / 1280 对内容敏感；375 只对壳层（底栏/概览卡片）敏感**。要在 375 也覆盖条目，
得先在该宽度导航进列表——本卡不做，留作后续（届时把探针改成「进列表后加一条」）。

## 重录

```bash
cd apps/life_launcher
flutter test test/shell_golden_test.dart --update-goldens --no-pub
```

## 平台边界

macOS + Flutter 默认字体录制；接 Linux CI 需按平台分目录（同 `feature_calendar/test/goldens/README.md`）。
