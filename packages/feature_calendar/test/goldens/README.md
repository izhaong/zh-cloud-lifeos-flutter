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

`day_view` / `year_view` 若将来引入「当前时间红线」之类依赖时刻的元素，同样要走
`clockProvider`，否则会在午夜前后抖动。
