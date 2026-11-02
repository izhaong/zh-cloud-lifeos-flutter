# 日历 golden 基线

三张图由 `../calendar_regression_test.dart` 的「三档断点（R-01 golden）」组产出：

| 文件 | 尺寸 | 视图 |
|---|---|---|
| `iphone_375_day.png` | 375×812 | 日视图 |
| `ipad_834_week.png` | 834×1112 | 周视图 |
| `desktop_1280_month.png` | 1280×800 | 月视图 + 侧栏 |

## 它们是**确定性**的（#331）

月/年视图的「今天」高亮曾经直接读 `DateTime.now()`，导致基线随执行日期漂移
（#330 重录时三张全变，最大 +32%），只能 `skip: true` 当摆设。

现在挂钟走 `clockProvider`（`lib/src/providers.dart`）：

- **生产**：默认 `DateTime.now`，行为不变；
- **测试**：`clockProvider.overrideWithValue(() => DateTime(2026, 10, 26))` 钉死，
  与 `anchorDateProvider` 的锚点一致，golden 因此可复现；
- 三处 `skip: true` 已去掉——它们是**门禁**，不是素材。

## 什么时候需要重录

只在**有意改观感**时：改完 UI 跑

```bash
cd packages/feature_calendar
flutter test test/calendar_regression_test.dart --update-goldens --no-pub
```

并在 PR 里说明改了什么、附上新图。

## 已知边界

1. **平台字体渲染**：golden 对字体/抗锯齿敏感，基线是在 macOS 上用 Flutter 默认字体录的。
   在 Linux/Windows 上跑可能整张不一致——本仓 CI 目前零 runner（#322），实际只有本机跑，
   所以暂不构成问题；**若将来接入 Linux CI，需要为每个平台各存一套基线**（或改用
   `--platform` 分目录）。
2. `day_view` 若将来引入「当前时间红线」之类依赖**时刻**（不只是日期）的元素，同样要走
   `clockProvider`，否则会在午夜前后抖动。

## 失败产物（`test/failures/`）不入库（#556）

golden 判红时 Flutter 会在同包 `test/failures/` 下写四张一次性诊断图
（`masterImage` / `testImage` / `isolatedDiff` / `maskedDiff`）。它们**不是基线**：
基线只有本目录 `test/goldens/` 里那几张。

这 28 张（calendar 8、task 12、note 8）曾被误提交进 develop，导致每跑一次红 golden
就把 8 个跟踪文件改成 `M`，`git add -A` 一步就把二进制 diff 混进 PR。
现已 `git rm --cached` 摘出索引并在 `.gitignore` 补 `**/test/failures/`。

要留证据时请自己拷走：`cp -R packages/*/test/failures /tmp/…`，别指望它进版本库。
