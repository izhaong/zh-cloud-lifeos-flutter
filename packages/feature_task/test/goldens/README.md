# task golden 基线

| 文件 | 尺寸 |
|---|---|
| `iphone_375_task.png` | 375×812 |
| `ipad_834_task.png` | 834×1112 |
| `desktop_1280_task.png` | 1280×800 |

## 为什么能当门禁

- 挂钟经 `clockProvider`（`lib/src/providers.dart`）钉到 `2026-10-26 09:30`——
  `task_scaffold.dart` 的两处分组（`已过期 / 今天 / 上午 / 下午`）读它而不是 `DateTime.now()`；
- 页面**钉在「今天」智能列表**（`TaskScaffold(openListId: 'smart.today')`）。
  默认列表页不按日期分组，换日期也不会红——第一版就栽在这，反证实验直接过了。

## 两个已验证判据

1. **确定性**：不 `--update-goldens` 连跑两次 → `All tests passed!`；
2. **因果性**：把注入日期换成 `2026-12-01` → 三张**全红**（分组变了）。

## 重录

```bash
cd packages/feature_task
flutter test test/task_golden_test.dart --update-goldens --no-pub
```

## 平台边界

基线在 macOS + Flutter 默认字体下录的；接 Linux CI 需按平台分目录（与 `feature_calendar/test/goldens/README.md` 同一条注意事项）。
