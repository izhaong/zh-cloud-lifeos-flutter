# 日历 golden 基线

四张图由 `../calendar_regression_test.dart` 的「三档断点（R-01 golden）」组产出：

| 文件 | 尺寸 | 视图 |
|---|---|---|
| `iphone_375_day.png` | 375×812 | 日视图 |
| `ipad_834_week.png` | 834×1112 | 周视图 |
| `desktop_1280_month.png` | 1280×800 | 月视图 + 侧栏 |
| `desktop_1280_month_dark.png` | 1280×800 | 月视图 + 侧栏（暗色，同夹具只改明暗） |

## 它们是**确定性**的（#331）

月/年视图的「今天」高亮曾经直接读 `DateTime.now()`，导致基线随执行日期漂移
（#330 重录时三张全变，最大 +32%），只能 `skip: true` 当摆设。

现在挂钟走 `clockProvider`（`lib/src/providers.dart`）：

- **生产**：默认 `DateTime.now`，行为不变；
- **测试**：`clockProvider.overrideWithValue(() => DateTime(2026, 10, 26))` 钉死，
  与 `anchorDateProvider` 的锚点一致，golden 因此可复现；
- 三处 `skip: true` 已去掉——它们是**门禁**，不是素材。

## 夹具的时刻形状（#553）

挂钟钉死还不够——**夹具里的 `startAt`/`endAt`/锚点也必须是本地墙钟**（`DateTime(...)`，
不要 `DateTime.utc(...)`），原因有两条，都已钉成同文件里的门禁用例
「golden 夹具：时刻须为本地墙钟且落在时间轴窗口内」：

1. 日/周视图按 `event.start.toLocal()` 落位（`lib/src/views/day_view.dart`），
   UTC 时刻的钟点会跟着**执行机器的时区**跑。改前的实测：同一份基线
   Asia/Shanghai 差 7.14%、UTC 差 3.57%、America/New_York 近乎为零——
   也就是「在任何时区都不能全绿」。
2. 时间轴只画 `dayStartHour`–`dayEndHour`（默认 8–18）。钟点落在窗外的事件
   在 golden 里**根本不出现**：图照样录得上，事件渲染的覆盖却静默没了。
   #553 重录时先踩到这一条（日视图录成空白），才把夹具钟点挪进窗口内。

因此现行四张基线是在**本地墙钟夹具**下重录的，任何时区执行都应全绿；
判据 = 分档跑 `TZ=UTC / Asia/Shanghai / America/New_York / Pacific/Kiritimati` 四次，
`All tests passed` 各一次。

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
